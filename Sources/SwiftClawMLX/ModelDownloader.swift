import Foundation
import Hub
@preconcurrency import MLXLMCommon
@preconcurrency import MLXEmbedders

// MARK: - LLM Download

/// Downloads an MLX LLM model to the local cache without loading it into memory.
///
/// Uses `MLXLMCommon.downloadModel` which fetches `*.safetensors` and `*.json` only.
/// This is faster than `loadModelContainer` because no weights are loaded into RAM.
///
/// - Parameters:
///   - modelId: HuggingFace model ID, e.g. `"mlx-community/Qwen3.5-9B-MLX-4bit"`
///   - progressHandler: Progress callback with fraction 0.0–1.0
/// - Returns: Local cache directory URL
public func downloadMLXModel(
    modelId: String,
    progressHandler: @Sendable @escaping (Double) -> Void = { _ in }
) async throws -> URL {
    let hub = HubApi()
    // Explicit MLXLMCommon.ModelConfiguration to avoid collision with MLXEmbedders.ModelConfiguration
    let configuration = MLXLMCommon.ModelConfiguration(id: modelId)
    return try await MLXLMCommon.downloadModel(hub: hub, configuration: configuration) { progress in
        progressHandler(progress.fractionCompleted)
    }
}

// MARK: - Embedding Model Download

/// Downloads an MLX embedding model to the local cache.
///
/// Uses `MLXEmbedders.loadModelContainer` which downloads and validates the model.
///
/// - Parameters:
///   - modelId: HuggingFace model ID, e.g. `"nomic-ai/nomic-embed-text-v1.5"`
///   - progressHandler: Progress callback with fraction 0.0–1.0
/// - Returns: Local cache directory URL
public func downloadMLXEmbeddingModel(
    modelId: String,
    progressHandler: @Sendable @escaping (Double) -> Void = { _ in }
) async throws -> URL {
    let hub = HubApi()
    let configuration = MLXEmbedders.ModelConfiguration(id: modelId)
    let _ = try await MLXEmbedders.loadModelContainer(
        hub: hub,
        configuration: configuration
    ) { progress in
        progressHandler(progress.fractionCompleted)
    }
    return configuration.modelDirectory(hub: hub)
}
