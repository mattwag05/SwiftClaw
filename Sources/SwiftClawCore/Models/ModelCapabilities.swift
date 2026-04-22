import Foundation

/// Static per-model capability metadata.
///
/// Today this only carries ``contextWindow`` (the maximum number of tokens the
/// model accepts in a single request) but is structured to grow — e.g. vision
/// support, reasoning support, tool-call support.
public struct ModelCapabilities: Sendable {
    public let contextWindow: Int

    public init(contextWindow: Int) {
        self.contextWindow = contextWindow
    }

    /// Looks up known capabilities by model ID with simple substring matching.
    /// Returns a default window of 8192 when no match.
    ///
    /// Matching is case-insensitive and first-match-wins, ordered from most
    /// specific to least specific. Unknown models fall back to a conservative
    /// 8192-token window.
    public static func forModel(id: String) -> ModelCapabilities {
        let lowered = id.lowercased()
        for (needle, window) in Self.knownModels where lowered.contains(needle) {
            return ModelCapabilities(contextWindow: window)
        }
        return ModelCapabilities(contextWindow: 8192)
    }

    /// Ordered from most specific to least specific. First match wins.
    private static let knownModels: [(String, Int)] = [
        ("qwen3-9b", 32768),
        ("qwen2.5-7b", 32768),
        ("qwen2.5", 32768),
        ("qwen3", 32768),
        ("llama-3", 8192),
        ("gpt-4o", 128_000),
        ("gpt-4", 8192),
        ("claude-3", 200_000),
        ("claude", 200_000),
    ]
}
