import Foundation

/// An adapter paired with its computed selection score.
public struct ScoredAdapter: Sendable {
    public let metadata: AdapterMetadata
    public let score: Double
}

/// Scores and selects a LoRA adapter for a given prompt.
///
/// Scoring formula (all components normalised to [0, 1]):
///   0.60 × tag overlap  +  0.25 × loss score  +  0.15 × recency score
public struct AdapterSelector: Sendable {

    public init() {}

    // MARK: - Public API

    /// Returns the best-scoring adapter above `threshold`, or `nil`.
    public func select(
        prompt: String,
        from adapters: [AdapterMetadata],
        forModel modelId: String,
        threshold: Double = 0.1
    ) -> AdapterMetadata? {
        let ranked = rank(prompt: prompt, from: adapters, forModel: modelId)
        return ranked.first.flatMap { $0.score >= threshold ? $0.metadata : nil }
    }

    /// Returns all adapters for `modelId` ranked by score (highest first).
    public func rank(
        prompt: String,
        from adapters: [AdapterMetadata],
        forModel modelId: String
    ) -> [ScoredAdapter] {
        let candidates = adapters.filter { $0.modelId == modelId }
        guard !candidates.isEmpty else { return [] }

        let keywords = promptKeywords(prompt)

        // Loss score: lower validation loss = higher score; scale across candidates.
        let losses = candidates.compactMap { $0.finalValidationLoss.map { Double($0) } }
        let minLoss = losses.min() ?? 0
        let maxLoss = losses.max() ?? 0
        let lossRange = maxLoss - minLoss

        let now = Date()

        return candidates.map { adapter in
            let tagScore = tagOverlap(keywords: keywords, tags: adapter.tags)
            let lossScore = lossComponent(
                loss: adapter.finalValidationLoss.map { Double($0) },
                min: minLoss, range: lossRange
            )
            let recencyScore = recency(createdAt: adapter.createdAt, now: now)
            let total = 0.60 * tagScore + 0.25 * lossScore + 0.15 * recencyScore
            return ScoredAdapter(metadata: adapter, score: total)
        }.sorted { $0.score > $1.score }
    }

    // MARK: - Scoring components

    private func tagOverlap(keywords: Set<String>, tags: [String]) -> Double {
        guard !keywords.isEmpty, !tags.isEmpty else { return 0 }
        let normalised = Set(tags.map { $0.lowercased() })
        let hits = keywords.intersection(normalised).count
        return Double(hits) / Double(max(keywords.count, normalised.count))
    }

    private func lossComponent(loss: Double?, min: Double, range: Double) -> Double {
        guard let loss else { return 0.5 } // neutral when no val loss recorded
        if range == 0 { return 1.0 }
        // Lower loss → higher score; map [min…max] → [1…0] then invert.
        return 1.0 - ((loss - min) / range)
    }

    private func recency(createdAt: Date, now: Date) -> Double {
        let days = now.timeIntervalSince(createdAt) / 86_400
        return 1.0 / (1.0 + days / 30.0)
    }

    // MARK: - Keyword extraction

    /// Lowercase alphabetic tokens, ≥3 chars, minus common stop words.
    private func promptKeywords(_ prompt: String) -> Set<String> {
        let stop: Set<String> = ["the", "and", "for", "with", "that", "this",
                                 "are", "was", "you", "can", "how", "what"]
        let words = prompt.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stop.contains($0) }
        return Set(words)
    }
}
