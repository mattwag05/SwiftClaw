import Foundation
import SwiftClawCore

/// Hash-based embedding provider — deterministic 768-dim L2-normalised vectors.
///
/// Uses a djb2 word-hash projection with no external dependencies.
/// Used as the default fallback when `MLXEmbeddingEngine` is unavailable or the
/// nomic model has not been downloaded.
public actor EmbeddingEngine: EmbeddingProvider {

    public static let defaultModelId = "nomic-ai/nomic-embed-text-v1.5"

    /// Dimensionality of the output vectors (static constant).
    public static let dimensions = 768

    /// `EmbeddingProvider` conformance — nonisolated so it can be read without actor-hopping.
    public nonisolated var dimensions: Int { Self.dimensions }

    public init() {}

    // MARK: - Public API

    /// Returns a 768-dim L2-normalised vector for `text`.
    /// Always returns a non-nil value (hash-based, deterministic).
    public func embed(_ text: String) async -> [Float]? {
        return hashEmbed(text)
    }

    /// Batch embed. Returns one optional vector per input string.
    public func embed(texts: [String]) async -> [[Float]?] {
        return texts.map { hashEmbed($0) }
    }

    // MARK: - Private

    /// Deterministic pseudo-embedding: word-level hash projection into `dimensions`-dim space,
    /// followed by L2 normalisation.  Semantically weaker than a trained model but fully
    /// deterministic and dependency-free.
    private func hashEmbed(_ text: String) -> [Float] {
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var vector = [Float](repeating: 0.0, count: EmbeddingEngine.dimensions)

        for word in words {
            // djb2 variant over UTF-8 bytes → UInt64
            let hash = word.utf8.reduce(UInt64(5381)) { h, c in
                h &* 31 &+ UInt64(c)
            }
            // Scatter the hash across the vector using overlapping 16-bit windows.
            for i in stride(from: 0, to: EmbeddingEngine.dimensions, by: 8) {
                let shift = UInt64(i % 64)
                let bits = (hash >> shift) & 0xFFFF
                // Map [0, 65535] → (-1, 1] so negative dimensions are possible.
                let value = Float(Int32(bits) - 32768) / 32768.0
                vector[i] += value
            }
        }

        // L2 normalise so cosine similarity is a dot product.
        let normSq = vector.reduce(Float(0)) { $0 + $1 * $1 }
        if normSq > 0 {
            let norm = normSq.squareRoot()
            vector = vector.map { $0 / norm }
        }

        return vector
    }
}
