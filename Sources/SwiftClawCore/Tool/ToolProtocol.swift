/// The wire format a backend uses for tool invocations.
///
/// - `json`: Standard OpenAI-compatible tool_calls / function-calling
///   (HTTPBackend default, Anthropic).
/// - `xml`: `<action name="…"><param name>…</param></action>` blocks
///   embedded in the model's text stream (MLXBackend default —
///   improves reliability on small local models like Qwen3.5).
public enum ToolProtocol: Sendable {
    case json
    case xml
}

public extension ModelBackend {
    /// Default tool protocol for backends that don't override it.
    var preferredToolProtocol: ToolProtocol { .json }
}
