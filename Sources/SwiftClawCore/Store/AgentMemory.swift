import Foundation

/// Persistent key-value memory for an agent.
///
/// Each namespace (typically an agent name) gets its own JSON file
/// at `~/.swiftclaw/memory/<namespace>.json`.
///
/// All keys and values are strings. Store structured data as JSON strings if needed.
public actor AgentMemory {
    private let file: URL
    private var store: [String: String]
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
        self.decoder = JSONDecoder()
        // Load existing memory if present
        if let data = try? Data(contentsOf: self.file),
           let loaded = try? self.decoder.decode([String: String].self, from: data) {
            self.store = loaded
        } else {
            self.store = [:]
        }
    }

    /// Read a value by key. Returns nil if not set.
    public func get(_ key: String) -> String? {
        store[key]
    }

    /// Write a value for a key, persisting to disk.
    public func set(_ key: String, value: String) throws {
        store[key] = value
        try persist()
    }

    /// Remove a key, persisting to disk.
    public func delete(_ key: String) throws {
        store.removeValue(forKey: key)
        try persist()
    }

    /// All stored key-value pairs.
    public func all() -> [String: String] {
        store
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
