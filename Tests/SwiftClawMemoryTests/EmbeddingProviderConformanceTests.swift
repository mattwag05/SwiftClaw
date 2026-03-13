import Testing
import Foundation
@testable import SwiftClawMemory
@testable import SwiftClawCore

// MARK: - Mock EmbeddingProvider with configurable dimensions

private actor FixedDimProvider: EmbeddingProvider {
    nonisolated let dimensions: Int
    private let value: Float

    init(dimensions: Int, value: Float = 1.0) {
        self.dimensions = dimensions
        self.value = value
    }

    func embed(_ text: String) async -> [Float]? {
        guard !text.isEmpty else { return nil }
        // Return L2-normalised vector of equal values
        let v = value / Float(dimensions).squareRoot()
        return Array(repeating: v, count: dimensions)
    }

    func embed(texts: [String]) async -> [[Float]?] {
        texts.map { text in
            text.isEmpty ? nil : Array(repeating: value / Float(dimensions).squareRoot(), count: dimensions)
        }
    }
}

@Suite("EmbeddingEngine conforms to EmbeddingProvider")
struct EmbeddingEngineProviderConformanceTests {

    @Test func embeddingEngineDimensionsAccessibleWithoutAwait() {
        let engine = EmbeddingEngine()
        #expect(engine.dimensions == EmbeddingEngine.dimensions)
    }

    @Test func embeddingEngineAsEmbeddingProvider() async {
        let provider: any EmbeddingProvider = EmbeddingEngine()
        #expect(provider.dimensions == 768)
        let v = await provider.embed("test")
        #expect(v?.count == 768)
    }
}

@Suite("MemoryStore with custom EmbeddingProvider")
struct MemoryStoreEmbeddingProviderTests {

    private func makeTempDir() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftclaw-test-\(UUID().uuidString)")
    }

    @Test func memoryStoreAcceptsCustomProvider() throws {
        let provider = FixedDimProvider(dimensions: 768)
        let store = try MemoryStore(baseDir: makeTempDir(), embeddingEngine: provider)
        _ = store
    }

    @Test func reindexSchedulesEmbeddingForAllEntries() async throws {
        let provider = FixedDimProvider(dimensions: 768)
        let store = try MemoryStore(baseDir: makeTempDir(), embeddingEngine: provider)

        try await store.set("k1", entry: MemoryEntry(key: "k1", content: "hello", source: "test"), layer: .working)
        try await store.set("k2", entry: MemoryEntry(key: "k2", content: "world", source: "test"), layer: .longTerm)

        // reindex should complete without throwing
        await store.reindex()

        // Entries should still be retrievable after reindex
        let e1 = await store.get("k1", layer: .working)
        #expect(e1 != nil)
        let e2 = await store.get("k2", layer: .longTerm)
        #expect(e2 != nil)

        await store.shutdown()
    }

    @Test func dimensionMismatchGraceFullyDegrades() async throws {
        // Store entries with a 4-dim provider, then search with a 768-dim provider.
        // The stored 4-dim blobs should not crash; semantic score falls back to 0.0.
        let smallProvider = FixedDimProvider(dimensions: 4)
        let tempDir = makeTempDir()
        let store = try MemoryStore(baseDir: tempDir, embeddingEngine: smallProvider)

        try await store.set(
            "content",
            entry: MemoryEntry(key: "content", content: "dimension mismatch test", source: "test"),
            layer: .longTerm
        )

        // Wait briefly for background embedding to complete
        try await Task.sleep(nanoseconds: 100_000_000)

        // Re-open store with 768-dim provider — stored blobs are 4-dim (16 bytes)
        // which won't match expectedEmbeddingBytes (768 * 4 = 3072 bytes).
        let bigProvider = FixedDimProvider(dimensions: 768)
        let store2 = try MemoryStore(baseDir: tempDir, embeddingEngine: bigProvider)

        // Search should not crash; it should return the entry via BM25/recency.
        let results = try await store2.search(query: "dimension mismatch test", layer: nil, topK: 5)
        #expect(!results.isEmpty)
        #expect(results.first?.entry.key == "content")

        await store.shutdown()
        await store2.shutdown()
    }
}
