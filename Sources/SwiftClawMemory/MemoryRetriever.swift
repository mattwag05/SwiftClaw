import Foundation

/// Pure-computation struct for hybrid retrieval scoring.
///
/// All methods are static — no stored state. MemoryStore uses these helpers when
/// building ScoredMemory results from the FTS5 + embedding candidates.
public struct MemoryRetriever: Sendable {

    // MARK: - Hybrid Score

    /// Compute the final hybrid relevance score from its four components.
    ///
    /// Weights:
    /// - Semantic similarity  50 %
    /// - BM25 (keyword)       25 %
    /// - Recency              15 %
    /// - Access frequency     10 %
    public static func hybridScore(
        semanticSimilarity: Float,
        bm25Normalized: Float,
        recencyScore: Float,
        accessFrequency: Float
    ) -> Float {
        semanticSimilarity * 0.50
            + bm25Normalized * 0.25
            + recencyScore   * 0.15
            + accessFrequency * 0.10
    }

    // MARK: - Component Scores

    /// Recency score in [0, 1]: 1.0 for now, decays as 1 / (1 + days).
    public static func recencyScore(from date: Date) -> Float {
        let daysSince = -date.timeIntervalSinceNow / 86400
        return Float(1.0 / (1.0 + max(0, daysSince)))
    }

    /// Access-frequency score in [0, 1]: saturates at count ≥ 10.
    public static func accessFrequencyScore(count: Int) -> Float {
        min(1.0, Float(count) / 10.0)
    }

    /// Normalise an FTS5 BM25 rank value to [0, 1].
    ///
    /// FTS5 BM25 ranks are *negative* — higher magnitude means *worse* match.
    /// We log-dampen the absolute value and invert so that a perfect match → 1.0
    /// and a poor match → 0.0.
    ///
    /// - Parameters:
    ///   - rank: Raw BM25 rank from FTS5 (typically a negative Double).
    ///   - maxExpected: Upper bound used for normalisation (default 10.0).
    public static func normalizeBM25(_ rank: Double, maxExpected: Double = 10.0) -> Float {
        let absRank = abs(rank)
        guard absRank > 0 else { return 1.0 }
        let normalized = log(1.0 + absRank) / log(1.0 + maxExpected)
        // Invert: high magnitude = worse match = lower score
        return Float(max(0.0, 1.0 - min(1.0, normalized)))
    }
}
