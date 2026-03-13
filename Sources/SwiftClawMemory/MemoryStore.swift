import Foundation
import GRDB
import SwiftClawCore

public actor MemoryStore: MemoryProvider {

    let dbPool: DatabasePool
    private let baseDir: URL
    var embeddingTasks: Set<Task<Void, Never>> = []
    private let embeddingEngine: any EmbeddingProvider

    // MARK: - Init

    public init(baseDir: URL? = nil, embeddingEngine: (any EmbeddingProvider)? = nil) throws {
        let dir: URL
        if let baseDir {
            dir = baseDir
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            dir = home.appendingPathComponent(".swiftclaw/memory")
        }

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.baseDir = dir

        let dbURL = dir.appendingPathComponent("memories.db")
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }
        let pool = try DatabasePool(path: dbURL.path, configuration: config)
        self.dbPool = pool

        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1-initial") { db in
            try db.execute(sql: """
                CREATE TABLE memories (
                    key TEXT NOT NULL,
                    layer TEXT NOT NULL CHECK(layer IN ('working', 'longTerm')),
                    content TEXT NOT NULL,
                    source TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL,
                    access_count INTEGER DEFAULT 0,
                    last_accessed_at REAL,
                    embedding BLOB,
                    PRIMARY KEY (key, layer)
                )
                """)

            try db.execute(sql: """
                CREATE VIRTUAL TABLE memories_fts USING fts5(
                    key, content,
                    content='memories',
                    content_rowid='rowid'
                )
                """)

            try db.execute(sql: """
                CREATE TRIGGER memories_ai AFTER INSERT ON memories BEGIN
                    INSERT INTO memories_fts(rowid, key, content) VALUES (new.rowid, new.key, new.content);
                END
                """)

            try db.execute(sql: """
                CREATE TRIGGER memories_ad AFTER DELETE ON memories BEGIN
                    INSERT INTO memories_fts(memories_fts, rowid, key, content) VALUES ('delete', old.rowid, old.key, old.content);
                END
                """)

            try db.execute(sql: """
                CREATE TRIGGER memories_au AFTER UPDATE OF key, content ON memories BEGIN
                    INSERT INTO memories_fts(memories_fts, rowid, key, content) VALUES ('delete', old.rowid, old.key, old.content);
                    INSERT INTO memories_fts(rowid, key, content) VALUES (new.rowid, new.key, new.content);
                END
                """)
        }
        try migrator.migrate(pool)

        self.embeddingEngine = embeddingEngine ?? EmbeddingEngine()

        // JSON migration from legacy files
        try Self.migrateJSONFiles(in: dir, dbPool: pool)
    }

    // MARK: - MemoryProvider

    public func get(_ key: String, layer: MemoryLayer?) async -> MemoryEntry? {
        if let layer {
            return try? await dbPool.read { db in
                let rows = try Row.fetchAll(db,
                    sql: "SELECT * FROM memories WHERE key = ? AND layer = ?",
                    arguments: [key, layer.rawValue])
                return rows.first.map { Self.entryFromRow($0) }
            }
        } else {
            // Search working first, then longTerm
            for searchLayer in [MemoryLayer.working, .longTerm] {
                if let entry = try? await dbPool.read({ db in
                    let rows = try Row.fetchAll(db,
                        sql: "SELECT * FROM memories WHERE key = ? AND layer = ?",
                        arguments: [key, searchLayer.rawValue])
                    return rows.first.map { Self.entryFromRow($0) }
                }) {
                    return entry
                }
            }
            return nil
        }
    }

    public func set(_ key: String, entry: MemoryEntry, layer: MemoryLayer) async throws {
        let now = Date().timeIntervalSince1970
        try await dbPool.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO memories
                        (key, layer, content, source, created_at, updated_at, access_count, last_accessed_at, embedding)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    key,
                    layer.rawValue,
                    entry.content,
                    entry.source,
                    now,
                    entry.updatedAt.timeIntervalSince1970,
                    entry.accessCount,
                    entry.lastAccessedAt.map { $0.timeIntervalSince1970 },
                    nil as Data?
                ]
            )
        }

        // Background embedding — schedule via actor-isolated helper so the task
        // can remove itself from embeddingTasks when it completes normally.
        scheduleEmbedding(key: key, layer: layer)
    }

    public func delete(_ key: String, layer: MemoryLayer) async throws {
        try await dbPool.write { db in
            try db.execute(
                sql: "DELETE FROM memories WHERE key = ? AND layer = ?",
                arguments: [key, layer.rawValue]
            )
        }
    }

    public func allEntries(layer: MemoryLayer?) async -> [MemoryEntry] {
        let rows: [Row]
        if let layer {
            rows = (try? await dbPool.read { db in
                try Row.fetchAll(db,
                    sql: "SELECT * FROM memories WHERE layer = ?",
                    arguments: [layer.rawValue])
            }) ?? []
        } else {
            rows = (try? await dbPool.read { db in
                try Row.fetchAll(db, sql: "SELECT * FROM memories")
            }) ?? []
        }
        return rows.map { Self.entryFromRow($0) }
    }

    public func clearLayer(_ layer: MemoryLayer) async throws {
        try await dbPool.write { db in
            try db.execute(
                sql: "DELETE FROM memories WHERE layer = ?",
                arguments: [layer.rawValue]
            )
        }
    }

    public func promote(keys: [String]) async throws {
        for key in keys {
            // Fetch from working
            guard let workingEntry = try? await dbPool.read({ db -> MemoryEntry? in
                let rows = try Row.fetchAll(db,
                    sql: "SELECT * FROM memories WHERE key = ? AND layer = ?",
                    arguments: [key, MemoryLayer.working.rawValue])
                return rows.first.map { Self.entryFromRow($0) }
            }) else {
                continue  // Skip silently if not found in working
            }

            let now = Date().timeIntervalSince1970
            // Upsert to longTerm and delete working in one transaction
            try await dbPool.write { db in
                try db.execute(
                    sql: """
                        INSERT OR REPLACE INTO memories
                            (key, layer, content, source, created_at, updated_at, access_count, last_accessed_at, embedding)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        key,
                        MemoryLayer.longTerm.rawValue,
                        workingEntry.content,
                        workingEntry.source,
                        now,
                        workingEntry.updatedAt.timeIntervalSince1970,
                        workingEntry.accessCount,
                        workingEntry.lastAccessedAt.map { $0.timeIntervalSince1970 },
                        nil as Data?
                    ]
                )
                try db.execute(
                    sql: "DELETE FROM memories WHERE key = ? AND layer = ?",
                    arguments: [key, MemoryLayer.working.rawValue]
                )
            }
        }
    }

    public func search(query: String, layer: MemoryLayer?, topK: Int) async throws -> [ScoredMemory] {
        // 1. Optionally obtain a query embedding for semantic scoring.
        let queryEmbedding: [Float]? = await embeddingEngine.embed(query)

        // 2. Run FTS5 search to get candidates with BM25 ranks.
        //    On no FTS match, fall back to all entries in the target layer(s).
        struct Candidate {
            let row: Row
            let bm25Rank: Double?  // nil = came from fallback scan, no FTS rank
        }

        let ftsSQL: String
        let fallbackSQL: String

        if let layer {
            ftsSQL = """
                SELECT m.rowid, m.key, m.layer, m.content, m.source,
                       m.created_at, m.updated_at, m.access_count,
                       m.last_accessed_at, m.embedding,
                       fts.rank AS bm25_rank
                FROM memories_fts fts
                JOIN memories m ON m.rowid = fts.rowid
                WHERE memories_fts MATCH ?
                  AND m.layer = ?
                ORDER BY fts.rank
                LIMIT 100
                """
            fallbackSQL = "SELECT *, NULL AS bm25_rank FROM memories WHERE layer = ?"
        } else {
            ftsSQL = """
                SELECT m.rowid, m.key, m.layer, m.content, m.source,
                       m.created_at, m.updated_at, m.access_count,
                       m.last_accessed_at, m.embedding,
                       fts.rank AS bm25_rank
                FROM memories_fts fts
                JOIN memories m ON m.rowid = fts.rowid
                WHERE memories_fts MATCH ?
                ORDER BY fts.rank
                LIMIT 100
                """
            fallbackSQL = "SELECT *, NULL AS bm25_rank FROM memories"
        }

        let candidates: [(row: Row, bm25Rank: Double?)] = try await dbPool.read { db in
            // Try FTS first
            let ftsArgs: StatementArguments = layer != nil
                ? [query, layer!.rawValue]
                : [query]
            let ftsRows = try Row.fetchAll(db, sql: ftsSQL, arguments: ftsArgs)

            if !ftsRows.isEmpty {
                return ftsRows.map { ($0, ($0["bm25_rank"] as Double?)) }
            }

            // Fallback: return all entries (no BM25 score)
            let fallbackArgs: StatementArguments = layer != nil ? [layer!.rawValue] : []
            let fallbackRows = try Row.fetchAll(db, sql: fallbackSQL, arguments: fallbackArgs)
            return fallbackRows.map { ($0, nil) }
        }

        // 3. Score each candidate using hybrid formula.
        let scored: [(entry: MemoryEntry, embData: Data?, bm25Rank: Double?, score: Float)] = candidates.map { candidate in
            let entry = Self.entryFromRow(candidate.row)
            let embData: Data? = candidate.row["embedding"]

            let bm25Score: Float
            if let rank = candidate.bm25Rank {
                bm25Score = MemoryRetriever.normalizeBM25(rank)
            } else {
                bm25Score = 0.0
            }

            let expectedEmbeddingBytes = embeddingEngine.dimensions * MemoryLayout<Float>.size
            let semanticScore: Float
            if let qEmb = queryEmbedding,
               let data = embData,
               data.count == expectedEmbeddingBytes {
                let entryEmb = Self.decodeEmbedding(data)
                if let entryEmb {
                    let sim = cosineSimilarity(qEmb, entryEmb)
                    // Cosine is in [-1, 1]; clamp to [0, 1]
                    semanticScore = max(0.0, sim)
                } else {
                    semanticScore = 0.0
                }
            } else {
                semanticScore = 0.0
            }

            let recency = MemoryRetriever.recencyScore(from: entry.updatedAt)
            let freq = MemoryRetriever.accessFrequencyScore(count: entry.accessCount)
            let finalScore = MemoryRetriever.hybridScore(
                semanticSimilarity: semanticScore,
                bm25Normalized: bm25Score,
                recencyScore: recency,
                accessFrequency: freq
            )

            return (entry, embData, candidate.bm25Rank, finalScore)
        }

        // 4. Sort by score descending, take top K.
        let topResults = scored
            .sorted { $0.score > $1.score }
            .prefix(topK)

        // 5. Bump access_count and last_accessed_at for returned entries.
        let now = Date().timeIntervalSince1970
        let returnedKeys: [(key: String, layer: String)] = topResults.map { item in
            // We need the layer value; read it back from the entry via allEntries isn't efficient.
            // Instead capture it from the row content: layer is a stored column.
            // We stored layer in the SELECT, so re-derive from the candidates mapping.
            // Simpler: fetch the layer from the candidates array by matching key.
            let candidateRow = candidates.first { Self.entryFromRow($0.row).key == item.entry.key }
            let layerVal: String = candidateRow?.row["layer"] ?? MemoryLayer.longTerm.rawValue
            return (item.entry.key, layerVal)
        }

        if !returnedKeys.isEmpty {
            try? await dbPool.write { db in
                for pair in returnedKeys {
                    try db.execute(
                        sql: """
                            UPDATE memories
                            SET access_count = access_count + 1,
                                last_accessed_at = ?
                            WHERE key = ? AND layer = ?
                            """,
                        arguments: [now, pair.key, pair.layer]
                    )
                }
            }
        }

        return topResults.map { ScoredMemory(entry: $0.entry, score: $0.score) }
    }

    public func shutdown() async {
        for task in embeddingTasks {
            task.cancel()
        }
        embeddingTasks.removeAll()
    }

    /// Clears all stored embedding blobs and re-embeds every entry in the background.
    ///
    /// Use this after switching to a different `EmbeddingProvider` (e.g. hash → MLX) so
    /// that stored vectors are consistent with the current provider's output dimensions.
    public func reindex() async {
        // 1. Null all embedding blobs so stale vectors don't bias search.
        try? await dbPool.write { db in
            try db.execute(sql: "UPDATE memories SET embedding = NULL")
        }

        // 2. Fetch all (key, layer) pairs and re-schedule background embedding.
        let pairs: [(key: String, layer: MemoryLayer)] = (try? await dbPool.read { db in
            try Row.fetchAll(db, sql: "SELECT key, layer FROM memories").compactMap { row in
                guard let key: String = row["key"],
                      let layerStr: String = row["layer"],
                      let layer = MemoryLayer(rawValue: layerStr) else { return nil }
                return (key, layer)
            }
        }) ?? []

        for (key, layer) in pairs {
            scheduleEmbedding(key: key, layer: layer)
        }
    }

    // MARK: - Private Helpers

    private func embedInBackground(key: String, layer: MemoryLayer) async {
        guard let content = await get(key, layer: layer)?.content else { return }
        guard let embedding = await embeddingEngine.embed(content) else { return }
        // Serialise as little-endian IEEE 754 floats
        let data = embedding.withUnsafeBytes { Data($0) }
        try? await dbPool.write { db in
            try db.execute(
                sql: "UPDATE memories SET embedding = ? WHERE key = ? AND layer = ?",
                arguments: [data, key, layer.rawValue]
            )
        }
    }

    private func scheduleEmbedding(key: String, layer: MemoryLayer) {
        // Create the task inside the actor. We forward the task handle to the
        // closure via a continuation so it can remove itself from embeddingTasks
        // when it completes, preventing unbounded Set growth.
        var task: Task<Void, Never>?
        task = Task {
            await self.embedInBackground(key: key, layer: layer)
            if let t = task { self.embeddingTasks.remove(t) }
        }
        if let t = task { embeddingTasks.insert(t) }
    }

    private func removeEmbeddingTask(_ task: Task<Void, Never>) {
        embeddingTasks.remove(task)
    }

    // MARK: - Embedding Helpers

    private static func decodeEmbedding(_ data: Data) -> [Float]? {
        guard !data.isEmpty, data.count % MemoryLayout<Float>.size == 0 else { return nil }
        return data.withUnsafeBytes { ptr in
            Array(ptr.bindMemory(to: Float.self))
        }
    }

    // Static so it can be called from GRDB sync closures without actor isolation issues
    private static func entryFromRow(_ row: Row) -> MemoryEntry {
        MemoryEntry(
            key: row["key"],
            content: row["content"],
            updatedAt: Date(timeIntervalSince1970: row["updated_at"]),
            source: row["source"],
            accessCount: row["access_count"] ?? 0,
            lastAccessedAt: (row["last_accessed_at"] as Double?).map { Date(timeIntervalSince1970: $0) }
        )
    }

    // MARK: - JSON Migration

    private static func migrateJSONFiles(in dir: URL, dbPool: DatabasePool) throws {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return
        }

        let jsonFiles = contents.filter {
            $0.pathExtension == "json" && !$0.lastPathComponent.hasSuffix(".json.migrated")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for file in jsonFiles {
            guard let data = try? Data(contentsOf: file),
                  let entries = try? decoder.decode([String: MemoryEntry].self, from: data) else {
                continue
            }

            let now = Date().timeIntervalSince1970
            for (_, entry) in entries {
                try dbPool.write { db in
                    try db.execute(
                        sql: """
                            INSERT OR REPLACE INTO memories
                                (key, layer, content, source, created_at, updated_at, access_count, last_accessed_at, embedding)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                            """,
                        arguments: [
                            entry.key,
                            MemoryLayer.longTerm.rawValue,
                            entry.content,
                            entry.source,
                            now,
                            entry.updatedAt.timeIntervalSince1970,
                            entry.accessCount,
                            entry.lastAccessedAt.map { $0.timeIntervalSince1970 },
                            nil as Data?
                        ]
                    )
                }
            }

            let migratedURL = file.deletingPathExtension().appendingPathExtension("json.migrated")
            try fm.moveItem(at: file, to: migratedURL)

            fputs("[memory] migrated \(entries.count) entries from \(file.lastPathComponent)\n", stderr)
        }
    }
}
