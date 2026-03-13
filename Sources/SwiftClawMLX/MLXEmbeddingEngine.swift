import Foundation
import MLX
@preconcurrency import MLXEmbedders
import SwiftClawCore

/// MLX-native embedding provider using the nomic-embed-text-v1.5 model.
///
/// Lazy-loads the model on the first `embed()` call.  Returns `nil` gracefully
/// if the model is unavailable so the caller can fall back to BM25 + recency scoring.
///
/// **Name collision note:** `MLXEmbedders.ModelContainer` and `MLXEmbedders.ModelConfiguration`
/// are distinct from the same-named types in `MLXLMCommon`.  Use the fully-qualified forms
/// below to avoid ambiguity.
public actor MLXEmbeddingEngine: EmbeddingProvider {

    // MARK: - EmbeddingProvider

    public nonisolated let dimensions: Int = 768

    // MARK: - Private State

    private var container: MLXEmbedders.ModelContainer?
    private let modelId: String
    private let progressHandler: (@Sendable (Double) -> Void)?

    // MARK: - Init

    public init(
        modelId: String = "nomic-ai/nomic-embed-text-v1.5",
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) {
        self.modelId = modelId
        self.progressHandler = progressHandler
    }

    // MARK: - EmbeddingProvider

    public func embed(_ text: String) async -> [Float]? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let c = try? await loadIfNeeded() else { return nil }

        let result: [Float] = await c.perform { model, tokenizer, pooler in
            let tokens = tokenizer.encode(text: text, addSpecialTokens: true)
            guard !tokens.isEmpty else {
                return Array(repeating: Float(0), count: 768)
            }
            let inputIds = stacked([MLXArray(tokens)])                    // [1, seqLen]
            let mask = MLXArray.ones(like: inputIds)                      // all-valid mask
            let tokenTypes = MLXArray.zeros(like: inputIds)
            let output = model(
                inputIds,
                positionIds: nil,
                tokenTypeIds: tokenTypes,
                attentionMask: mask
            )
            let pooled = pooler(output, normalize: true, applyLayerNorm: true)
            eval(pooled)
            // pooled has shape [1, 768]; flatten to [768]
            return pooled.flattened().asArray(Float.self)
        }

        return result
    }

    public func embed(texts: [String]) async -> [[Float]?] {
        var results: [[Float]?] = []
        results.reserveCapacity(texts.count)
        for text in texts {
            results.append(await embed(text))
        }
        return results
    }

    // MARK: - Private

    private func loadIfNeeded() async throws -> MLXEmbedders.ModelContainer {
        if let existing = container { return existing }

        let ph = progressHandler
        let configuration = MLXEmbedders.ModelConfiguration(id: modelId)
        let progressClosure: @Sendable (Progress) -> Void
        if let h = ph {
            progressClosure = { progress in h(progress.fractionCompleted) }
        } else {
            progressClosure = { _ in }
        }
        let loaded: MLXEmbedders.ModelContainer = try await MLXEmbedders.loadModelContainer(
            configuration: configuration,
            progressHandler: progressClosure
        )
        container = loaded
        return loaded
    }
}
