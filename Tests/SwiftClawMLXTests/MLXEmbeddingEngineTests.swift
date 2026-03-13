import Testing
import Foundation
@testable import SwiftClawMLX
@testable import SwiftClawCore

@Suite("MLXEmbeddingEngine")
struct MLXEmbeddingEngineTests {

    @Test func conformsToEmbeddingProviderProtocol() {
        // Compile-time check: MLXEmbeddingEngine can be used as any EmbeddingProvider.
        let engine: any EmbeddingProvider = MLXEmbeddingEngine()
        #expect(engine.dimensions == 768)
    }

    @Test func dimensionsAreNonisolated() {
        // dimensions must be readable without await (nonisolated).
        let engine = MLXEmbeddingEngine()
        let dim = engine.dimensions
        #expect(dim == 768)
    }

    @Test func embedReturnsNilForEmptyString() async {
        let engine = MLXEmbeddingEngine()
        // Empty string should return nil without attempting to load the model.
        let result = await engine.embed("")
        #expect(result == nil)
    }

    @Test func embedReturnsNilForWhitespaceOnlyString() async {
        let engine = MLXEmbeddingEngine()
        let result = await engine.embed("   ")
        #expect(result == nil)
    }

    /// Integration test — only runs when the nomic model is cached locally.
    @Test func embedReturns768DimVectorWhenModelCached() async throws {
        let modelId = "nomic-ai/nomic-embed-text-v1.5"
        let cachePath = NSHomeDirectory() + "/Library/Caches/models/" + modelId
        guard FileManager.default.fileExists(atPath: cachePath) else {
            // Skip when model is not cached — not a failure.
            return
        }

        let engine = MLXEmbeddingEngine(modelId: modelId)
        let result = await engine.embed("hello world")
        #expect(result != nil)
        #expect(result?.count == 768)

        // L2-normalised output: norm should be ≈ 1.0
        if let v = result {
            let normSq = v.reduce(Float(0)) { $0 + $1 * $1 }
            #expect(abs(normSq.squareRoot() - 1.0) < 1e-3, "Vector should be L2-normalised")
        }
    }
}
