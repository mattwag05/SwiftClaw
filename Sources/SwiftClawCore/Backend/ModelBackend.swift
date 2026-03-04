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

        return GenerationResponse(
            content: text,
            toolCalls: toolCalls,
            finishReason: finishReason
        )
    }
}
