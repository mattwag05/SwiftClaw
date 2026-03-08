import Testing
import Foundation
@testable import SwiftClawMLX

@Suite("AdapterStore")
struct AdapterStoreTests {

    // MARK: - Backward compatibility

    @Test("Decodes old metadata without tags/description fields")
    func backwardCompat() throws {
        let json = """
        {
          "name": "old-adapter",
          "modelId": "mlx-community/Qwen3.5-9B-MLX-4bit",
          "createdAt": "2025-01-01T00:00:00Z",
          "iterations": 50,
          "rank": 8,
          "numLayers": 8,
          "sessionCount": 2
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let meta = try decoder.decode(AdapterMetadata.self, from: json)

        #expect(meta.name == "old-adapter")
        #expect(meta.tags == [])
        #expect(meta.description == nil)
    }

    @Test("Decodes new metadata with tags and description")
    func decodeWithTags() throws {
        let json = """
        {
          "name": "new-adapter",
          "modelId": "mlx-community/Qwen3.5-9B-MLX-4bit",
          "createdAt": "2025-06-01T00:00:00Z",
          "iterations": 100,
          "rank": 8,
          "numLayers": 8,
          "sessionCount": 3,
          "tags": ["swift", "coding"],
          "description": "Trained on Swift coding sessions"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let meta = try decoder.decode(AdapterMetadata.self, from: json)

        #expect(meta.tags == ["swift", "coding"])
        #expect(meta.description == "Trained on Swift coding sessions")
    }

    @Test("Tags survive save/load round-trip via AdapterStore")
    func tagRoundTrip() throws {
        // Use a temp directory to avoid polluting ~/.swiftclaw/adapters
        let tmp = FileManager.default.temporaryDirectory
            .appending(path: "swiftclaw-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Build a store pointing at the temp dir
        var store = try AdapterStore(adaptersURL: tmp)

        var meta = AdapterMetadata(
            name: "tag-test",
            modelId: "test-model",
            iterations: 10,
            rank: 4,
            numLayers: 4,
            sessionCount: 1,
            tags: ["swift", "tools"],
            description: "Test adapter"
        )
        try store.saveMetadata(meta)

        let loaded = try store.loadMetadata(name: "tag-test")
        #expect(loaded.tags == ["swift", "tools"])
        #expect(loaded.description == "Test adapter")

        // Mutate tags and re-save
        meta.tags = ["swift"]
        meta.tags.append("ml")
        try store.saveMetadata(meta)

        let reloaded = try store.loadMetadata(name: "tag-test")
        #expect(reloaded.tags == ["swift", "ml"])
    }
}
