import Foundation

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
    public let sessionId: String?
    private var isRunning: Bool = false

    /// Create a new session with a fresh conversation history.
    public init(
        agent: Agent,
        backend: any ModelBackend,
        config: SessionConfiguration = SessionConfiguration(),
        sessionId: String? = nil
    ) {
        self.agent = agent
        self.backend = backend
        self.config = config
        self.sessionId = sessionId
        self.messages = [
            Message(role: .system, content: agent.configuration.systemPrompt)
        ]
    }

    /// Restore a session from previously saved messages.
    /// The saved messages are used as-is (including any system message they contain).
    public init(
        agent: Agent,
        backend: any ModelBackend,
        config: SessionConfiguration = SessionConfiguration(),
        sessionId: String,
        restoredMessages: [Message]
    ) {
        self.agent = agent
        self.backend = backend
        self.config = config
        self.sessionId = sessionId
        self.messages = restoredMessages
    }

    /// Save the current conversation to a store.
    public func save(to store: any SessionStore, metadata: SessionMetadata) async throws {
        guard let id = sessionId else { return }
        var meta = metadata
        meta.updatedAt = Date()
        try await store.save(sessionId: id, messages: messages, metadata: meta)
    }

    /// Run the agentic loop for a user prompt, emitting events as they occur.
    public func respond(to prompt: String) -> AsyncThrowingStream<SessionEvent, Error> {
        let agent = self.agent
        let backend = self.backend
        let config = self.config

        if isRunning {
            return AsyncThrowingStream { continuation in
                continuation.yield(.warning("Already generating — please wait"))
                continuation.yield(.done)
                continuation.finish()
            }
        }
        isRunning = true

        return AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
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
                    await self.setRunning(false)
                    continuation.finish()
                } catch {
                    await self.setRunning(false)
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
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

        // Trim oldest non-system messages if we've exceeded the history limit.
        // Walk backwards from the trim point to avoid splitting a tool-call group
        // (assistant message with tool calls + subsequent tool result messages).
        if messages.count > config.maxTotalMessages {
            let keepCount = max(1, config.maxTotalMessages - 1)
            var trimmed = Array(messages.dropFirst().suffix(keepCount))
            // If the trim point landed inside a tool-call group (assistant + its tool
            // results), drop leading orphaned tool results to keep the history coherent.
            // Guard: never trim all messages — keep at least the most recent one.
            while trimmed.count > 1, trimmed.first?.role == .tool {
                trimmed.removeFirst()
            }
            messages = [messages[0]] + trimmed
        }

        var lastResponse = GenerationResponse(content: "", finishReason: .stop)
        for _ in 0..<config.maxToolRoundTrips {
            let stream: AsyncThrowingStream<StreamChunk, Error> = backend.generate(
                messages: messages,
                tools: agent.toolRegistry.definitions,
                config: agent.configuration.generationConfig
            )

            var accumulatedText = ""
            var collectedToolCalls: [ToolCallRequest] = []
            var streamFinishReason: StreamChunk.FinishReason = .stop
            var seenEndThink = false

            for try await chunk in stream {
                if Task.isCancelled { break }

                if let text = chunk.text {
                    accumulatedText += text

                    if !seenEndThink {
                        if let thinkEnd = accumulatedText.range(of: "</think>") {
                            seenEndThink = true
                            // Emit only the suffix after </think>, trimmed
                            let suffix = String(accumulatedText[thinkEnd.upperBound...])
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            if !suffix.isEmpty {
                                continuation.yield(.textDelta(suffix, isThinking: false))
                            }
                        } else if accumulatedText.count > 2000 {
                            // Fallback: assume no thinking block after 2000 chars (non-thinking models)
                            seenEndThink = true
                            continuation.yield(.textDelta(text, isThinking: false))
                        } else {
                            // Still in thinking: signal UI to show indicator (empty text)
                            continuation.yield(.textDelta("", isThinking: true))
                        }
                    } else {
                        continuation.yield(.textDelta(text, isThinking: false))
                    }
                }

                if let tools = chunk.toolCalls {
                    collectedToolCalls.append(contentsOf: tools)
                }

                if let reason = chunk.finishReason {
                    streamFinishReason = reason
                }
            }

            // Strip <think> blocks from accumulated text
            var cleanedText = accumulatedText
            if let r = cleanedText.range(of: "</think>") {
                cleanedText = String(cleanedText[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let r = cleanedText.range(of: "<think>[\\s\\S]*$", options: .regularExpression) {
                cleanedText = String(cleanedText[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Strip tool call XML from text
            if cleanedText.contains("<tool_call>") {
                cleanedText = cleanedText.replacingOccurrences(
                    of: "<tool_call>[\\s\\S]*?</tool_call>",
                    with: "",
                    options: .regularExpression
                )
            }
            if cleanedText.contains("<function=") {
                cleanedText = cleanedText.replacingOccurrences(
                    of: "<function=[\\s\\S]*?</function>",
                    with: "",
                    options: .regularExpression
                )
            }
            cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

            let mappedFinishReason: StreamChunk.FinishReason = collectedToolCalls.isEmpty
                ? (streamFinishReason == .length ? .length : .stop)
                : .toolCall
            let response = GenerationResponse(
                content: cleanedText,
                toolCalls: collectedToolCalls,
                finishReason: mappedFinishReason
            )
            lastResponse = response

            messages.append(Message(
                role: .assistant,
                content: response.content,
                toolCalls: response.toolCalls.isEmpty ? nil : response.toolCalls
            ))

            // No tool calls — this is the final answer
            if response.toolCalls.isEmpty {
                continuation.yield(.turn(response))
                if response.finishReason == .length {
                    continuation.yield(.warning("Response truncated — model hit token limit"))
                }
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

        // Max round-trips reached: emit last response as partial answer + warning
        continuation.yield(.turn(lastResponse))
        continuation.yield(.warning("Exceeded max tool round-trips (\(config.maxToolRoundTrips))"))
        continuation.yield(.done)
    }

    private func setRunning(_ value: Bool) { isRunning = value }

    /// Current conversation history (read-only snapshot).
    public var conversationHistory: [Message] {
        messages
    }
}
