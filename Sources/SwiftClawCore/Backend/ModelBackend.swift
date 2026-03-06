/// Protocol for LLM inference backends.
///
/// Conforming types must implement the streaming `generate` method.
/// A non-streaming convenience is provided via default extension.
public protocol ModelBackend: Sendable {
    func generate(
        messages: [Message],
        tools: [ToolDefinition],
        config: GenerationConfig
    ) -> AsyncThrowingStream<StreamChunk, Error>
}

extension ModelBackend {
    /// Non-streaming convenience that collects the stream into a single response.
    public func generate(
        messages: [Message],
        tools: [ToolDefinition],
        config: GenerationConfig
    ) async throws -> GenerationResponse {
        var text = ""
        var toolCalls: [ToolCallRequest] = []
        var finishReason: StreamChunk.FinishReason = .stop

        for try await chunk in generate(messages: messages, tools: tools, config: config) {
            if let t = chunk.text { text += t }
            if let tc = chunk.toolCalls { toolCalls.append(contentsOf: tc) }
            if let fr = chunk.finishReason { finishReason = fr }
        }

        // Strip Qwen3.5 tool call XML blocks (emitted when fallback parser fires).
        // Handles both <tool_call>...</tool_call> (template format) and
        // bare <function=name>...</function> (text-injection format).
        if text.contains("<tool_call>") {
            text = text.replacingOccurrences(
                of: "<tool_call>[\\s\\S]*?</tool_call>",
                with: "",
                options: .regularExpression
            )
        }
        if text.contains("<function=") {
            text = text.replacingOccurrences(
                of: "<function=[\\s\\S]*?</function>",
                with: "",
                options: .regularExpression
            )
        }

        // Strip reasoning blocks emitted by Qwen3.5.
        // The model streams thinking content then closes with </think> (opening tag may be implicit).
        if let thinkEnd = text.range(of: "</think>") {
            text = String(text[thinkEnd.upperBound...])
        } else if text.contains("<think>") {
            // Unclosed <think>: model stopped mid-thought — drop everything from <think> onward
            text = text.replacingOccurrences(
                of: "<think>[\\s\\S]*$",
                with: "",
                options: .regularExpression
            )
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return GenerationResponse(
            content: text,
            toolCalls: toolCalls,
            finishReason: finishReason
        )
    }
}
