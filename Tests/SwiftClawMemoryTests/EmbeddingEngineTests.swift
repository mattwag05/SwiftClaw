import Testing
import Foundation
@testable import SwiftClawMemory

@Suite("EmbeddingEngine Tests")
struct EmbeddingEngineTests {

    @Test func embedReturnsCorrectDimension() async {
        let engine = EmbeddingEngine()
        let vector = await engine.embed("hello world")
        #expect(vector != nil)
        #expect(vector?.count == EmbeddingEngine.dimensions)
    }

    @Test func embedIsDeterministic() async {
        let engine = EmbeddingEngine()
        let v1 = await engine.embed("hello world")
        let v2 = await engine.embed("hello world")
        #expect(v1 != nil)
        #expect(v2 != nil)
        if let a = v1, let b = v2 {
            #expect(a == b, "Same input should produce identical vectors")
        }
    }

    @Test func embedEmptyStringDoesNotCrash() async {
        let engine = EmbeddingEngine()
        // Empty string → all-zero bag-of-words; L2 norm = 0 → vector stays all-zeros.
        // The important thing is it doesn't crash.
        let vector = await engine.embed("")
        // Either nil or a valid-length vector is acceptable.
        if let v = vector {
            #expect(v.count == EmbeddingEngine.dimensions)
        }
    }

    @Test func embedDifferentTextsProduceDifferentVectors() async {
        let engine = EmbeddingEngine()
        let v1 = await engine.embed("apple banana cherry")
        let v2 = await engine.embed("dog cat mouse")
        guard let a = v1, let b = v2 else {
            Issue.record("embed returned nil unexpectedly")
            return
        }
        // They should not be identical
        #expect(a != b, "Different texts should (usually) produce different vectors")
    }

    @Test func batchEmbedMatchesSingleEmbed() async {
        let engine = EmbeddingEngine()
        let texts = ["one fish", "two fish", "red fish"]
        let batch = await engine.embed(texts: texts)
        #expect(batch.count == texts.count)
        for (i, text) in texts.enumerated() {
            let single = await engine.embed(text)
            #expect(batch[i] == single, "Batch embed for '\(text)' should match single embed")
        }
    }

    @Test func embedIsL2Normalised() async {
        let engine = EmbeddingEngine()
        guard let vector = await engine.embed("normalisation check") else {
            Issue.record("embed returned nil")
            return
        }
        let normSq = vector.reduce(Float(0)) { $0 + $1 * $1 }
        let norm = normSq.squareRoot()
        #expect(abs(norm - 1.0) < 1e-4, "Vector should be L2-normalised, norm=\(norm)")
    }
}
