import Testing
import Foundation
@testable import SwiftClawCore

// MARK: - Mock EmbeddingProvider for compile-time conformance check

private actor MockEmbeddingProvider: EmbeddingProvider {
    nonisolated let dimensions: Int = 4

    func embed(_ text: String) async -> [Float]? {
        guard !text.isEmpty else { return nil }
        return [1.0, 0.0, 0.0, 0.0]
    }

    func embed(texts: [String]) async -> [[Float]?] {
        return texts.map { text in
            text.isEmpty ? nil : [1.0, 0.0, 0.0, 0.0]
        }
    }
}

@Suite("EmbeddingProvider Protocol Tests")
struct EmbeddingProviderTests {

    @Test func mockProviderConformsToProtocol() async {
        let provider: any EmbeddingProvider = MockEmbeddingProvider()
        #expect(provider.dimensions == 4)
        let v = await provider.embed("hello")
        #expect(v?.count == 4)
    }

    @Test func mockProviderBatchEmbed() async {
        let provider: any EmbeddingProvider = MockEmbeddingProvider()
        let results = await provider.embed(texts: ["a", "", "b"])
        #expect(results.count == 3)
        #expect(results[0] != nil)
        #expect(results[1] == nil)
        #expect(results[2] != nil)
    }

    @Test func dimensionsAccessibleWithoutAwait() {
        // nonisolated var means no actor hop required
        let provider: any EmbeddingProvider = MockEmbeddingProvider()
        let dim = provider.dimensions
        #expect(dim == 4)
    }
}
