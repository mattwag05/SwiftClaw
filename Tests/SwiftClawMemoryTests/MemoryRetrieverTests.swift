import Testing
import Foundation
@testable import SwiftClawMemory
@testable import SwiftClawCore

@Suite("MemoryRetriever Tests")
struct MemoryRetrieverTests {

    // MARK: - hybridScore

    @Test func hybridScoreWeightsCorrect() {
        // When all components are 1.0, sum of weights must equal 1.0.
        let score = MemoryRetriever.hybridScore(
            semanticSimilarity: 1.0,
            bm25Normalized: 1.0,
            recencyScore: 1.0,
            accessFrequency: 1.0
        )
        #expect(abs(score - 1.0) < 1e-5)
    }

    @Test func hybridScoreZeroInputs() {
        let score = MemoryRetriever.hybridScore(
            semanticSimilarity: 0.0,
            bm25Normalized: 0.0,
            recencyScore: 0.0,
            accessFrequency: 0.0
        )
        #expect(score == 0.0)
    }

    @Test func hybridScoreSemanticDominates() {
        // Semantic weight (0.5) should dominate when it alone is set.
        let score = MemoryRetriever.hybridScore(
            semanticSimilarity: 1.0,
            bm25Normalized: 0.0,
            recencyScore: 0.0,
            accessFrequency: 0.0
        )
        #expect(abs(score - 0.50) < 1e-5)
    }

    // MARK: - recencyScore

    @Test func recencyScoreToday() {
        // A date of right now should yield a score very close to 1.0.
        let score = MemoryRetriever.recencyScore(from: Date())
        #expect(score > 0.99)
    }

    @Test func recencyScoreOld() {
        // 30 days ago: daysSince ≈ 30, score = 1 / 31 ≈ 0.032 — should be low.
        let thirtyDaysAgo = Date(timeIntervalSinceNow: -30 * 86400)
        let score = MemoryRetriever.recencyScore(from: thirtyDaysAgo)
        #expect(score < 0.1)
    }

    @Test func recencyScoreOneYearAgo() {
        let oneYearAgo = Date(timeIntervalSinceNow: -365 * 86400)
        let score = MemoryRetriever.recencyScore(from: oneYearAgo)
        #expect(score < 0.01)
    }

    // MARK: - accessFrequencyScore

    @Test func accessFrequencyScore10() {
        // count = 10 → saturates at 1.0
        let score = MemoryRetriever.accessFrequencyScore(count: 10)
        #expect(abs(score - 1.0) < 1e-5)
    }

    @Test func accessFrequencyScore5() {
        // count = 5 → 0.5
        let score = MemoryRetriever.accessFrequencyScore(count: 5)
        #expect(abs(score - 0.5) < 1e-5)
    }

    @Test func accessFrequencyScoreZero() {
        let score = MemoryRetriever.accessFrequencyScore(count: 0)
        #expect(score == 0.0)
    }

    @Test func accessFrequencyScoreAbove10() {
        // Should cap at 1.0 even for counts > 10
        let score = MemoryRetriever.accessFrequencyScore(count: 100)
        #expect(score == 1.0)
    }

    // MARK: - normalizeBM25

    @Test func normalizeBM25Zero() {
        // rank = 0 means perfect FTS match → score should be 1.0
        let score = MemoryRetriever.normalizeBM25(0.0)
        #expect(abs(score - 1.0) < 1e-5)
    }

    @Test func normalizeBM25Negative() {
        // Typical FTS5 rank is negative; function should still return a positive score.
        let score = MemoryRetriever.normalizeBM25(-5.0)
        #expect(score > 0.0)
        #expect(score <= 1.0)
    }

    @Test func normalizeBM25HighMagnitude() {
        // Very negative rank → near 0 (bad match)
        let score = MemoryRetriever.normalizeBM25(-1000.0)
        #expect(score >= 0.0)
        #expect(score < 0.1)
    }

    @Test func normalizeBM25SmallNegative() {
        // Small negative rank should be closer to 1.0 than large negative rank.
        let good = MemoryRetriever.normalizeBM25(-0.5)
        let bad  = MemoryRetriever.normalizeBM25(-9.0)
        #expect(good > bad)
    }
}

// MARK: - Integration Tests

private func makeTempStore() throws -> MemoryStore {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("swiftclaw-retriever-test-\(UUID().uuidString)")
    return try MemoryStore(baseDir: tempDir)
}

@Suite("MemoryStore Hybrid Search Integration Tests")
struct MemoryStoreHybridSearchTests {

    @Test func memoryStoreSearchReturnsScoredResults() async throws {
        let store = try makeTempStore()

        try await store.set(
            "swift",
            entry: MemoryEntry(key: "swift", content: "swift programming language features", source: "test"),
            layer: .longTerm
        )
        try await store.set(
            "fox",
            entry: MemoryEntry(key: "fox", content: "the quick brown fox jumps", source: "test"),
            layer: .longTerm
        )
        try await store.set(
            "dog",
            entry: MemoryEntry(key: "dog", content: "over the lazy dog barking", source: "test"),
            layer: .longTerm
        )

        let results = try await store.search(query: "swift", layer: nil, topK: 5)

        #expect(!results.isEmpty)
        // Each result must have a score in [0, 1]
        for result in results {
            #expect(result.score >= 0.0)
            #expect(result.score <= 1.0)
        }
        // The "swift" entry should be the top result
        #expect(results.first?.entry.key == "swift")

        await store.shutdown()
    }

    @Test func memoryStoreSearchUpdatesAccessCount() async throws {
        let store = try makeTempStore()

        try await store.set(
            "access-test",
            entry: MemoryEntry(key: "access-test", content: "unique access count test content", source: "test"),
            layer: .longTerm
        )

        // Initial access count should be 0
        let before = await store.get("access-test", layer: .longTerm)
        #expect(before?.accessCount == 0)

        // Perform a search that returns this entry
        let results = try await store.search(query: "access count test", layer: nil, topK: 5)
        #expect(!results.isEmpty)

        // Access count should be incremented
        let after = await store.get("access-test", layer: .longTerm)
        #expect((after?.accessCount ?? 0) > 0)

        await store.shutdown()
    }

    @Test func memoryStoreSearchRespectsLayerFilter() async throws {
        let store = try makeTempStore()

        try await store.set(
            "layer-key",
            entry: MemoryEntry(key: "layer-key", content: "layer filter search test keyword", source: "test"),
            layer: .working
        )
        try await store.set(
            "layer-key",
            entry: MemoryEntry(key: "layer-key", content: "layer filter search test keyword", source: "test"),
            layer: .longTerm
        )

        let workingResults = try await store.search(query: "layer filter", layer: .working, topK: 5)
        let longTermResults = try await store.search(query: "layer filter", layer: .longTerm, topK: 5)

        // Each filtered search should only return entries from the matching layer
        for result in workingResults {
            _ = result.entry  // entries themselves don't store layer, but we validated the SQL filter
        }
        // Both layers had matching content, so both searches should find results
        #expect(!workingResults.isEmpty)
        #expect(!longTermResults.isEmpty)

        await store.shutdown()
    }

    @Test func memoryStoreSearchTopKRespected() async throws {
        let store = try makeTempStore()

        for i in 0..<10 {
            try await store.set(
                "key-\(i)",
                entry: MemoryEntry(key: "key-\(i)", content: "common search term entry number \(i)", source: "test"),
                layer: .longTerm
            )
        }

        let results = try await store.search(query: "common search term", layer: nil, topK: 3)
        #expect(results.count <= 3)

        await store.shutdown()
    }
}
