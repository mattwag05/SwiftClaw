/// Token usage reported by the LLM provider.
public struct TokenUsage: Sendable, Codable, Equatable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
    /// Tokens read from the prompt cache (Anthropic cache_control only).
    public let cacheReadTokens: Int?
    /// Tokens written to the prompt cache (Anthropic cache_control only).
    public let cacheCreationTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens
        case completionTokens
        case totalTokens
        case cacheReadTokens
        case cacheCreationTokens
    }

    public init(
        promptTokens: Int,
        completionTokens: Int,
        totalTokens: Int,
        cacheReadTokens: Int? = nil,
        cacheCreationTokens: Int? = nil
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        promptTokens = try c.decode(Int.self, forKey: .promptTokens)
        completionTokens = try c.decode(Int.self, forKey: .completionTokens)
        totalTokens = try c.decode(Int.self, forKey: .totalTokens)
        cacheReadTokens = try c.decodeIfPresent(Int.self, forKey: .cacheReadTokens)
        cacheCreationTokens = try c.decodeIfPresent(Int.self, forKey: .cacheCreationTokens)
    }
}

/// A single chunk from a streaming LLM generation.
public struct StreamChunk: Sendable {
    public let text: String?
    /// Reasoning/thinking content from models that use a dedicated reasoning field
    /// (e.g. Gemma 4 `reasoning`, DeepSeek-R1). Distinct from `<think>` tag
    /// detection which is handled by Session's text buffering.
    public let thinking: String?
    public let toolCalls: [ToolCallRequest]?
    public let finishReason: FinishReason?
    public let tokenUsage: TokenUsage?

    public enum FinishReason: String, Sendable, Codable {
        case stop
        case toolCall = "tool_calls"
        case length
    }

    public init(
        text: String? = nil,
        thinking: String? = nil,
        toolCalls: [ToolCallRequest]? = nil,
        finishReason: FinishReason? = nil,
        tokenUsage: TokenUsage? = nil
    ) {
        self.text = text
        self.thinking = thinking
        self.toolCalls = toolCalls
        self.finishReason = finishReason
        self.tokenUsage = tokenUsage
    }
}
