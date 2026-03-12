import Foundation
import Testing
@testable import SwiftClawCore

// MARK: - MemoryEntry Tests

@Test func memoryEntryCodableRoundTrip() throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let entry = MemoryEntry(
        key: "pref-editor",
        content: "User prefers Neovim",
        updatedAt: Date(timeIntervalSince1970: 1_000_000),
        source: "session-abc"
    )
    let data = try encoder.encode(entry)
    let decoded = try decoder.decode(MemoryEntry.self, from: data)
    #expect(decoded.key == entry.key)
    #expect(decoded.content == entry.content)
    #expect(decoded.source == entry.source)
}

@Test func memoryEntryBackwardCompatDecoding() throws {
    // JSON without accessCount or lastAccessedAt (legacy format)
    let json = """
    {
        "key": "test-key",
        "content": "test content",
        "updatedAt": "2024-01-01T00:00:00Z",
        "source": "test-source"
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let entry = try decoder.decode(MemoryEntry.self, from: json.data(using: .utf8)!)
    #expect(entry.key == "test-key")
    #expect(entry.accessCount == 0)
    #expect(entry.lastAccessedAt == nil)
}
