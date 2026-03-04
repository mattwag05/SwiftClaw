/// Complete response from a non-streaming LLM generation.
public struct GenerationResponse: Sendable {
    public let content: String
    public let toolCalls: [ToolCallRequest]
    public let finishReason: StreamChunk.FinishReason

    public init(
        content: String,
        toolCalls: [ToolCallRequest] = [],
        finishReason: StreamChunk.FinishReason = .stop
    ) {
        self.content = content
        self.toolCalls = toolCalls
        self.finishReason = finishReason
    }
}

/// Configuration for text generation.
public struct GenerationConfig: Sendable {
    public var temperature: Float
    public var maxTokens: Int
    public var topP: Float?

    public init(temperature: Float = 0.7, maxTokens: Int = 4096, topP: Float? = nil) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
    }
}
