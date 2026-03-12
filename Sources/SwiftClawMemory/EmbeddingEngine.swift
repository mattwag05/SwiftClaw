import Foundation
import MLXLMCommon

/// Actor that converts text into fixed-length float vectors for semantic similarity.
///
/// Phase 3 uses a deterministic hash-based projection (768-dim, L2-normalised).
/// When the nomic-embed-text MLX model is cached, this stub logs a notice and still
/// falls back to the hash projection — full ML embedding is deferred to Phase 4.
public actor EmbeddingEngine {

    public static let defaultModelId = "nomic-ai/nomic-embed-text-v1.5-MLX"

    /// Dimensionality of the output vectors.
    public static let dimensions = 768

    private let modelId: String

    public init(modelId: String = EmbeddingEngine.defaultModelId) {
        self.modelId = modelId
        // Check whether the model is cached and emit an informational message.
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/models")
            .appendingPathComponent(modelId)
        if FileManager.default.fileExists(atPath: cacheDir.path) {
            fputs("[memory] embedding model found at \(cacheDir.path), using hash-based fallback (ML embedding deferred to Phase 4)\n", stderr)
        } else {
            fputs("[memory] embedding model not found, using hash-based fallback\n", stderr)
        }
    }

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
