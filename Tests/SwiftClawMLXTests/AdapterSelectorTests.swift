import Testing
import Foundation
@testable import SwiftClawMLX

@Suite("AdapterSelector")
struct AdapterSelectorTests {

    // MARK: - Helpers

    private func makeAdapter(
        name: String,
        modelId: String = "test-model",
        tags: [String] = [],
        finalValidationLoss: Float? = nil,
        createdAt: Date = Date()
    ) -> AdapterMetadata {
        AdapterMetadata(
            name: name,
            modelId: modelId,
            createdAt: createdAt,
            iterations: 100,
            rank: 8,
            numLayers: 8,
            finalTrainingLoss: nil,
            finalValidationLoss: finalValidationLoss,
            sessionCount: 1,
            tags: tags
        )
    }

    private let selector = AdapterSelector()

    // MARK: - Tag matching

    @Test("Returns adapter when tags overlap with prompt keywords")
    func tagMatch() {
        let adapters = [
            makeAdapter(name: "coding-helper", tags: ["swift", "coding"]),
            makeAdapter(name: "writing-helper", tags: ["writing", "prose"])
        ]
        let result = selector.select(prompt: "help me write swift coding", from: adapters, forModel: "test-model", threshold: 0.0)
        #expect(result?.name == "coding-helper")
    }

    @Test("Returns nil when model ID does not match any adapter")
    func modelFilter() {
        let adapters = [makeAdapter(name: "other", modelId: "other-model", tags: ["swift"])]
        let result = selector.select(prompt: "swift coding", from: adapters, forModel: "test-model", threshold: 0.0)
        #expect(result == nil)
    }

    @Test("Returns nil when all scores are below threshold")
    func threshold() {
        let adapters = [makeAdapter(name: "unrelated", tags: [])]
        let result = selector.select(prompt: "xyz", from: adapters, forModel: "test-model", threshold: 0.9)
        #expect(result == nil)
    }

    @Test("Returns nil when no adapters provided")
    func emptyAdapters() {
        let result = selector.select(prompt: "swift", from: [], forModel: "test-model", threshold: 0.0)
        #expect(result == nil)
    }

    @Test("No tags on any adapter — loss+recency still ranks")
    func noTagsRanksByLoss() {
        let old = makeAdapter(name: "old-low-loss", tags: [], finalValidationLoss: 0.1,
                              createdAt: Date().addingTimeInterval(-90 * 86_400))
        let recent = makeAdapter(name: "recent-high-loss", tags: [], finalValidationLoss: 0.9,
                                 createdAt: Date())
        let ranked = selector.rank(prompt: "something", from: [old, recent], forModel: "test-model")
        // recent wins on recency (0.15 weight) vs old wins on loss (0.25 weight)
        // old: loss=1.0, recency≈0.25  →  0.25*1.0 + 0.15*0.25 ≈ 0.2875
        // recent: loss=0.0, recency≈1.0 → 0.25*0.0 + 0.15*1.0 ≈ 0.15
        #expect(ranked.first?.metadata.name == "old-low-loss")
    }

    @Test("Tie-breaking: lower loss wins when tags equal")
    func tieBrakingByLoss() {
        let a = makeAdapter(name: "a", tags: ["swift"], finalValidationLoss: 0.1)
        let b = makeAdapter(name: "b", tags: ["swift"], finalValidationLoss: 0.9)
        let ranked = selector.rank(prompt: "swift code", from: [a, b], forModel: "test-model")
        #expect(ranked.first?.metadata.name == "a")
    }

    @Test("Recency score decreases as adapter ages")
    func recencyDecay() {
        let recent = makeAdapter(name: "recent", createdAt: Date())
        let old    = makeAdapter(name: "old",    createdAt: Date().addingTimeInterval(-365 * 86_400))
        let rankedRecent = selector.rank(prompt: "x", from: [recent], forModel: "test-model")
        let rankedOld    = selector.rank(prompt: "x", from: [old],    forModel: "test-model")
        let recencyRecent = rankedRecent.first!.score
        let recencyOld    = rankedOld.first!.score
        #expect(recencyRecent > recencyOld)
    }

    @Test("rank() returns all candidates for modelId")
    func rankReturnsAll() {
        let adapters = [
            makeAdapter(name: "a", tags: ["swift"]),
            makeAdapter(name: "b", tags: ["ml"]),
            makeAdapter(name: "c", modelId: "other-model")
        ]
        let ranked = selector.rank(prompt: "something", from: adapters, forModel: "test-model")
        #expect(ranked.count == 2)
    }
}
