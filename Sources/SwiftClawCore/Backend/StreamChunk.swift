/// Token usage reported by the LLM provider.
public struct TokenUsage: Sendable, Codable, Equatable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int

    public init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

/// A single chunk from a streaming LLM generation.
public struct StreamChunk: Sendable {
    public let text: String?
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
        toolCalls: [ToolCallRequest]? = nil,
        finishReason: FinishReason? = nil,
        tokenUsage: TokenUsage? = nil
    ) {
        self.text = text
        self.toolCalls = toolCalls
        self.finishReason = finishReason
        self.tokenUsage = tokenUsage
    }
}
