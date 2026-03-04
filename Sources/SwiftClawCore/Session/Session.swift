/// The agentic loop: manages conversation state and orchestrates
/// LLM generation → tool execution → result feedback cycles.
///
/// Session is an actor to protect the mutable `messages` array
/// under Swift 6 strict concurrency.
public actor Session {
    private var messages: [Message]
    private let agent: Agent
    private let backend: any ModelBackend
    private let config: SessionConfiguration

    public init(
        agent: Agent,
        backend: any ModelBackend,
        config: SessionConfiguration = SessionConfiguration()
    ) {
        self.agent = agent
        self.backend = backend
        self.config = config
        self.messages = [
            Message(role: .system, content: agent.configuration.systemPrompt)
        ]
    }

    /// Run the agentic loop for a user prompt, emitting events as they occur.
    public func respond(to prompt: String) -> AsyncThrowingStream<SessionEvent, Error> {
        let agent = self.agent
        let backend = self.backend
        let config = self.config

        return AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self else {
                    continuation.finish(throwing: SwiftClawError.sessionClosed)
                    return
                }
                do {
                    try await self.runLoop(
                        prompt: prompt,
                        agent: agent,
                        backend: backend,
                        config: config,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// The core agentic loop.
    private func runLoop(
        prompt: String,
        agent: Agent,
        backend: any ModelBackend,
        config: SessionConfiguration,
        continuation: AsyncThrowingStream<SessionEvent, Error>.Continuation
    ) async throws {
        messages.append(Message(role: .user, content: prompt))

        for _ in 0..<config.maxToolRoundTrips {
            let response = try await backend.generate(
                messages: messages,
                tools: agent.toolRegistry.definitions,
                config: agent.configuration.generationConfig
            )

            messages.append(Message(
                role: .assistant,
                content: response.content,
                toolCalls: response.toolCalls.isEmpty ? nil : response.toolCalls
            ))

            // No tool calls — this is the final answer
            if response.toolCalls.isEmpty {
                continuation.yield(.turn(response))
                continuation.yield(.done)
                return
            }

            // Execute each tool call and feed results back
            for call in response.toolCalls {
                continuation.yield(.toolCallStart(id: call.id, name: call.name))
                let result = try await agent.toolRegistry.execute(
                    name: call.name, arguments: call.arguments
                )
                continuation.yield(.toolResult(id: call.id, result))
                messages.append(Message(
                    role: .tool,
                    content: result.content,
                    toolCallId: call.id
                ))
            }
            // Loop back: LLM sees tool results and generates next turn
        }

        throw SwiftClawError.maxToolRoundTripsExceeded(config.maxToolRoundTrips)
    }

    /// Current conversation history (read-only snapshot).
    public var conversationHistory: [Message] {
        messages
    }
}
