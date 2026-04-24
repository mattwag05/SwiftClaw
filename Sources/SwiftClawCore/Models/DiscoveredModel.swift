import Foundation

/// A model discovered via API or filesystem scan.
public struct DiscoveredModel: Sendable, Identifiable, Equatable {
    /// Model tag — `"qwen2.5:7b"` (Ollama), `"gpt-4o-mini"` (OpenAI),
    /// `"mlx-community/Qwen3.5-9B-MLX-4bit"` (MLX cache).
    public let id: String
    public let size: Int64?
    /// Parameter count, human-friendly (`"9B"`, `"700M"`).
    public let parameterSize: String?
    /// Quantization label as the source reports it — `"Q4_K_M"` from Ollama,
    /// `"4-bit"` from the MLX scanner. Not normalized across sources.
    public let quantization: String?
    public let family: String?
    public let source: Source

    public enum Source: String, Sendable {
        case ollama
        case openai
        case mlx
    }

    public init(
        id: String,
        size: Int64? = nil,
        parameterSize: String? = nil,
        quantization: String? = nil,
        family: String? = nil,
        source: Source
    ) {
        self.id = id
        self.size = size
        self.parameterSize = parameterSize
        self.quantization = quantization
        self.family = family
        self.source = source
    }
}
