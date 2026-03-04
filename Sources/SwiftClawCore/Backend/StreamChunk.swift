/// A single chunk from a streaming LLM generation.
public struct StreamChunk: Sendable {
    public let text: String?
    public let toolCalls: [ToolCallRequest]?
    public let finishReason: FinishReason?

    public enum FinishReason: String, Sendable {
        case stop
        case toolCall = "tool_calls"
        case length
    }

    public init(
        text: String? = nil,
        toolCalls: [ToolCallRequest]? = nil,
        finishReason: FinishReason? = nil
    ) {
        self.text = text
        self.toolCalls = toolCalls
        self.finishReason = finishReason
    }
}
