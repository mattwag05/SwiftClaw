import Foundation

/// A single persisted memory entry with metadata.
public struct MemoryEntry: Codable, Sendable {
    public let key: String
    public let content: String
    public let updatedAt: Date
    public let source: String  // session ID or "migrated"
    public let accessCount: Int      // default 0
    public let lastAccessedAt: Date? // default nil

    public init(
        key: String,
        content: String,
        updatedAt: Date = Date(),
        source: String,
        accessCount: Int = 0,
        lastAccessedAt: Date? = nil
    ) {
        self.key = key
        self.content = content
        self.updatedAt = updatedAt
        self.source = source
        self.accessCount = accessCount
        self.lastAccessedAt = lastAccessedAt
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case key, content, updatedAt, source, accessCount, lastAccessedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        content = try container.decode(String.self, forKey: .content)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        source = try container.decode(String.self, forKey: .source)
        accessCount = try container.decodeIfPresent(Int.self, forKey: .accessCount) ?? 0
        lastAccessedAt = try container.decodeIfPresent(Date.self, forKey: .lastAccessedAt)
    }
}
