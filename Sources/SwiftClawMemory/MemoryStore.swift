import Foundation
import GRDB
import SwiftClawCore

public actor MemoryStore: MemoryProvider {

    let dbPool: DatabasePool
    private let baseDir: URL
    var embeddingTasks: Set<Task<Void, Never>> = []

    // MARK: - Init

    public init(baseDir: URL? = nil) throws {
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

        // Background embedding stub (no-op for Phase 2)
        let task = Task<Void, Never> { [weak self] in
            await self?.embedInBackground(key: key, layer: layer)
        }
        embeddingTasks.insert(task)
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
        let rows: [Row]

        if let layer {
            rows = try await dbPool.read { db in
                try Row.fetchAll(db,
                    sql: """
                        SELECT m.*, fts.rank
                        FROM memories m
                        JOIN memories_fts fts ON m.rowid = fts.rowid
                        WHERE memories_fts MATCH ?
                          AND m.layer = ?
                        ORDER BY fts.rank
                        LIMIT ?
                        """,
                    arguments: [query, layer.rawValue, topK])
            }
        } else {
            rows = try await dbPool.read { db in
                try Row.fetchAll(db,
                    sql: """
                        SELECT m.*, fts.rank
                        FROM memories m
                        JOIN memories_fts fts ON m.rowid = fts.rowid
                        WHERE memories_fts MATCH ?
                        ORDER BY fts.rank
                        LIMIT ?
                        """,
                    arguments: [query, topK])
            }
        }

        return rows.map { row -> ScoredMemory in
            let entry = Self.entryFromRow(row)
            // BM25 rank is negative (lower = worse). Normalize to 0.0-1.0.
            let rank: Double = row["rank"] ?? -10.0
            let score = Float(max(0.0, 1.0 + rank / 10.0))
            return ScoredMemory(entry: entry, score: score)
        }
    }

    public func shutdown() async {
        for task in embeddingTasks {
            task.cancel()
        }
        embeddingTasks.removeAll()
    }

    // MARK: - Private Helpers

    private func embedInBackground(key: String, layer: MemoryLayer) async {
        // Phase 3: embed and store vector. No-op stub for Phase 2.
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
