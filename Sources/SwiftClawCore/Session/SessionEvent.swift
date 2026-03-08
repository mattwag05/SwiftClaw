/// Events emitted by a session during the agentic loop.
public enum SessionEvent: Sendable {
    /// The LLM decided to call a tool.
    case toolCallStart(id: String, name: String)
    /// A tool finished executing.
    case toolResult(id: String, ToolResult)
    /// A complete assistant turn (with full content).
    case turn(GenerationResponse)
    /// The session produced a final answer (no more tool calls).
    case done
    /// A non-fatal warning (e.g. truncated response, max round-trips exceeded).
    case warning(String)
}
