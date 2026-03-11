import Foundation

/// A single persisted memory entry with metadata.
public struct MemoryEntry: Codable, Sendable {
    public let key: String
    public let content: String
    public let updatedAt: Date
    public let source: String  // session ID or "migrated"

    public init(key: String, content: String, updatedAt: Date = Date(), source: String) {
        self.key = key
        self.content = content
        self.updatedAt = updatedAt
        self.source = source
    }
}
