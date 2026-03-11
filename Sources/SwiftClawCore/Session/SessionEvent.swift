/// Events emitted by a session during the agentic loop.
public enum SessionEvent: Sendable {
    /// The LLM decided to call a tool.
    case toolCallStart(id: String, name: String)
    /// A tool call is awaiting user approval before execution.
    case toolCallPending(id: String, name: String, arguments: String)
    /// A tool call was denied by the user.
    case toolCallDenied(id: String, name: String)
    /// A tool finished executing.
    case toolResult(id: String, ToolResult)
    /// A text token from the model (streaming).
    case textDelta(String)
    /// A reasoning/thinking token from the model (streaming, Qwen3.5 <think> blocks).
    case thinkingDelta(String)
    /// A complete assistant turn (with full content). Emitted after all textDelta/thinkingDelta events.
    case turn(GenerationResponse)
    /// The session produced a final answer (no more tool calls).
    case done
    /// A non-fatal warning (e.g. truncated response, max round-trips exceeded).
    case warning(String)
    /// Memory consolidation ran and wrote new facts.
    case memoryUpdated(keys: [String])
}
