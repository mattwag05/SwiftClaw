import Foundation

public protocol MemoryProvider: Actor {
    func get(_ key: String, layer: MemoryLayer?) async -> MemoryEntry?  // nil = search both layers, working first
    func set(_ key: String, entry: MemoryEntry, layer: MemoryLayer) async throws
    func delete(_ key: String, layer: MemoryLayer) async throws
    func search(query: String, layer: MemoryLayer?, topK: Int) async throws -> [ScoredMemory]
    func promote(keys: [String]) async throws  // moves working → long-term; skips missing; overwrites existing; deletes working copy
    func allEntries(layer: MemoryLayer?) async -> [MemoryEntry]
    func clearLayer(_ layer: MemoryLayer) async throws
    func shutdown() async
}

public enum MemoryLayer: String, Codable, Sendable {
    case working    // session-scoped, cleared on session end
    case longTerm   // persists across sessions
}

public struct ScoredMemory: Sendable {
    public let entry: MemoryEntry
    public let score: Float  // 0.0–1.0, hybrid relevance

    public init(entry: MemoryEntry, score: Float) {
        self.entry = entry
        self.score = score
    }
}
