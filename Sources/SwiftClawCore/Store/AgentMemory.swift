import Foundation

/// Persistent key-value memory for an agent.
///
/// Each namespace (typically an agent name) gets its own JSON file
/// at `~/.swiftclaw/memory/<namespace>.json`.
///
/// Values are stored as `MemoryEntry` structs (with metadata).
/// Old files with `[String: String]` format are migrated automatically on first load.
public actor AgentMemory {
    private let file: URL
    private var store: [String: MemoryEntry]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(namespace: String, baseDir: URL? = nil) throws {
        let base = baseDir ?? FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".swiftclaw")
        let memoryDir = base.appendingPathComponent("memory")
        try FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        self.file = memoryDir.appendingPathComponent("\(namespace).json")
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        // Load existing memory — try new format first, fall back to legacy [String: String]
        if let data = try? Data(contentsOf: self.file) {
            if let loaded = try? self.decoder.decode([String: MemoryEntry].self, from: data) {
                self.store = loaded
            } else if let legacy = try? self.decoder.decode([String: String].self, from: data) {
                // Migrate: wrap each string value as a MemoryEntry
                var migrated: [String: MemoryEntry] = [:]
                for (key, value) in legacy {
                    migrated[key] = MemoryEntry(
                        key: key,
                        content: value,
                        updatedAt: .distantPast,
                        source: "migrated"
                    )
                }
                self.store = migrated
            } else {
                self.store = [:]
            }
        } else {
            self.store = [:]
        }
    }

    /// Read a memory entry by key. Returns nil if not set.
    public func get(_ key: String) -> MemoryEntry? {
        store[key]
    }

    /// Write a memory entry, persisting to disk.
    public func set(_ key: String, entry: MemoryEntry) throws {
        store[key] = entry
        try persist()
    }

    /// Remove a key, persisting to disk.
    public func delete(_ key: String) throws {
        store.removeValue(forKey: key)
        try persist()
    }

    /// All stored entries.
    public func all() -> [String: MemoryEntry] {
        store
    }

    /// Render all entries as a human-readable bullet list, sorted by key.
    public func formatted() -> String {
        guard !store.isEmpty else { return "(no memories stored)" }
        return store.keys.sorted()
            .compactMap { key -> String? in
                guard let entry = store[key] else { return nil }
                return "- \(entry.key): \(entry.content)"
            }
            .joined(separator: "\n")
    }

    private func persist() throws {
        do {
            let data = try encoder.encode(store)
            try data.write(to: file, options: .atomic)
        } catch {
            throw SwiftClawError.storageError("Memory write failed: \(error.localizedDescription)")
        }
    }
}
