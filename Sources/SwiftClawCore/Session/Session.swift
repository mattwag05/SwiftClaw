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
    private let approvalDelegate: (any ToolApprovalDelegate)?
    private let processMonitor: ProcessMonitor?

    // Memory support (optional)
    private let memory: (any MemoryProvider)?
    private let consolidator: MemoryConsolidator
    private let compressor: ContextCompressor
    private var turnsSinceConsolidation: Int = 0

    /// Create a new session with a fresh conversation history.
    public init(
        agent: Agent,
        backend: any ModelBackend,
        config: SessionConfiguration = SessionConfiguration(),
        sessionId: String? = nil,
        memory: (any MemoryProvider)? = nil,
        approvalDelegate: (any ToolApprovalDelegate)? = nil,
        processMonitor: ProcessMonitor? = nil
    ) {
        self.agent = agent
        self.backend = backend
        self.config = config
        self.sessionId = sessionId
        self.memory = memory
        self.approvalDelegate = approvalDelegate
        self.processMonitor = processMonitor
        consolidator = MemoryConsolidator()
        compressor = ContextCompressor()
        messages = [
            Message(role: .system, content: agent.configuration.systemPrompt),
        ]
    }

    /// Restore a session from previously saved messages.
    /// The saved messages are used as-is (including any system message they contain).
    public init(
        agent: Agent,
        backend: any ModelBackend,
        config: SessionConfiguration = SessionConfiguration(),
        sessionId: String,
        restoredMessages: [Message],
        memory: (any MemoryProvider)? = nil,
        approvalDelegate: (any ToolApprovalDelegate)? = nil,
        processMonitor: ProcessMonitor? = nil
    ) {
        self.agent = agent
        self.backend = backend
        self.config = config
        self.sessionId = sessionId
        self.memory = memory
        self.approvalDelegate = approvalDelegate
        self.processMonitor = processMonitor
        consolidator = MemoryConsolidator()
        compressor = ContextCompressor()
        messages = restoredMessages
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
        let approvalDelegate = self.approvalDelegate

        if isRunning {
            return AsyncThrowingStream { continuation in
                continuation.yield(.warning("Already generating — please wait"))
                continuation.yield(.done)
                continuation.finish()
            }
        }
        isRunning = true

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
                        approvalDelegate: approvalDelegate,
                        continuation: continuation
                    )
                    await self.setRunning(false)
                    continuation.finish()
                } catch {
                    await self.setRunning(false)
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
        approvalDelegate: (any ToolApprovalDelegate)?,
        continuation: AsyncThrowingStream<SessionEvent, Error>.Continuation
    ) async throws {
        // 1. Memory injection: rebuild system message with relevant remembered facts.
        //    Always reset messages[0] to the base prompt first so stale memories
        //    from a prior turn don't linger when this turn has no relevant hits.
        if config.memoryEnabled, let mem = memory {
            let basePrompt = agent.configuration.systemPrompt
            if !messages.isEmpty {
                messages[0] = Message(role: .system, content: basePrompt)
            }
            let relevant = (try? await mem.search(query: prompt, layer: nil, topK: config.retrievalTopK)) ?? []
            let filtered = relevant.filter { $0.score >= config.retrievalThreshold }
            if !filtered.isEmpty {
                let factsText = filtered.map { scored in
                    "- \(scored.entry.key): \(scored.entry.content)"
                }.joined(separator: "\n")
                let enriched = basePrompt + "\n\n## Relevant Memories\n" + factsText
                if !messages.isEmpty {
                    messages[0] = Message(role: .system, content: enriched)
                }
            }
        }

        // 2. Append user message
        messages.append(Message(role: .user, content: prompt))

        // 3. Context compression (before hard trim)
        if let threshold = config.compressionTokenThreshold,
           compressor.estimateTokens(messages) > threshold
        {
            // If memory enabled, consolidate the compressible region first
            if config.memoryEnabled, let mem = memory, let sid = sessionId {
                let compressible = Array(messages.dropFirst().dropLast(config.compressionKeepRecent))
                if !compressible.isEmpty {
                    let keys = (try? await consolidator.consolidate(
                        messages: compressible,
                        using: backend,
                        config: agent.configuration.generationConfig,
                        into: mem,
                        layer: .working,
                        sessionId: sid
                    )) ?? []
                    if !keys.isEmpty {
                        continuation.yield(.memoryUpdated(keys: keys))
                    }
                }
            }
            // Compress
            let compressed = (try? await compressor.compress(
                messages,
                using: backend,
                config: agent.configuration.generationConfig,
                keepRecent: config.compressionKeepRecent
            )) ?? messages
            messages = compressed
            continuation.yield(.warning("Context compressed — older messages summarized"))
        }

        // 4. Hard trim (fallback / overflow guard)
        if messages.count > config.maxTotalMessages {
            let keepCount = max(1, config.maxTotalMessages - 1)
            var trimmed = Array(messages.dropFirst().suffix(keepCount))
            while trimmed.count > 1, trimmed.first?.role == .tool {
                trimmed.removeFirst()
            }
            messages = [messages[0]] + trimmed
        }

        // 5. Agentic loop
        var lastResponse = GenerationResponse(content: "", finishReason: .stop)
        for _ in 0 ..< config.maxToolRoundTrips {
            // Streaming generation with think-block detection.
            // Text chunks are buffered until we know if they're thinking or real content.
            // Buffering per-chunk (not concatenated) so each can be flushed individually.
            var bufferedChunks: [String] = [] // Pre-</think> chunks, waiting for classification
            var postThinkText = "" // Confirmed real text (after </think>)
            var sawThinkEnd = false
            var accumulatedToolCalls: [ToolCallRequest] = []
            var finishReason: StreamChunk.FinishReason = .stop
            var tokenUsage: TokenUsage?

            let stream: AsyncThrowingStream<StreamChunk, Error> = backend.generate(
                messages: messages,
                tools: agent.toolRegistry.definitions,
                config: agent.configuration.generationConfig
            )

            for try await chunk in stream {
                if let text = chunk.text {
                    if sawThinkEnd {
                        // After </think> — yield real content immediately
                        postThinkText += text
                        let cleaned = stripToolCallXML(text)
                        if !cleaned.isEmpty {
                            continuation.yield(.textDelta(cleaned))
                        }
                    } else {
                        bufferedChunks.append(text)
                        // Check if </think> appeared anywhere in the accumulated buffer
                        let combined = bufferedChunks.joined()
                        if let range = combined.range(of: "</think>") {
                            sawThinkEnd = true
                            var thinkPart = String(combined[combined.startIndex ..< range.lowerBound])
                            thinkPart = thinkPart
                                .replacingOccurrences(of: "<think>", with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            let afterThink = String(combined[range.upperBound...])
                            bufferedChunks = []
                            if !thinkPart.isEmpty {
                                continuation.yield(.thinkingDelta(thinkPart))
                            }
                            if !afterThink.isEmpty {
                                let cleaned = stripToolCallXML(afterThink)
                                if !cleaned.isEmpty {
                                    continuation.yield(.textDelta(cleaned))
                                }
                                postThinkText = afterThink
                            }
                        }
                    }
                }
                // Dedicated reasoning field (Gemma 4, DeepSeek-R1) — bypass </think> buffering
                if let thinking = chunk.thinking, !thinking.isEmpty {
                    continuation.yield(.thinkingDelta(thinking))
                }
                if let tc = chunk.toolCalls { accumulatedToolCalls.append(contentsOf: tc) }
                if let fr = chunk.finishReason { finishReason = fr }
                if let tu = chunk.tokenUsage { tokenUsage = tu }
            }

            // If no </think> found, flush each buffered chunk individually as text deltas
            if !sawThinkEnd, !bufferedChunks.isEmpty {
                for buffered in bufferedChunks {
                    let cleaned = stripToolCallXML(buffered)
                    if !cleaned.isEmpty {
                        continuation.yield(.textDelta(cleaned))
                    }
                }
                postThinkText = bufferedChunks.joined()
            }

            // Build clean final text (same cleanup as the non-streaming convenience method)
            var cleanText = stripToolCallXML(postThinkText).trimmingCharacters(in: .whitespacesAndNewlines)
            // Handle unclosed <think> (model stopped mid-thought)
            if cleanText.contains("<think>") {
                cleanText = cleanText.replacingOccurrences(
                    of: "<think>[\\s\\S]*$", with: "", options: .regularExpression
                )
                cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let response = GenerationResponse(
                content: cleanText,
                toolCalls: accumulatedToolCalls,
                finishReason: finishReason,
                tokenUsage: tokenUsage
            )
            lastResponse = response

            messages.append(Message(
                role: .assistant,
                content: response.content,
                toolCalls: response.toolCalls.isEmpty ? nil : response.toolCalls
            ))

            if response.toolCalls.isEmpty {
                continuation.yield(.turn(response))
                if response.finishReason == .length {
                    continuation.yield(.warning("Response truncated — model hit token limit"))
                }
                continuation.yield(.done)

                // 6. Post-turn consolidation
                if config.memoryEnabled, let mem = memory, let sid = sessionId {
                    turnsSinceConsolidation += 1
                    if turnsSinceConsolidation >= config.consolidationInterval {
                        turnsSinceConsolidation = 0
                        let recent = messages.suffix(config.consolidationInterval * 4)
                        let keys = (try? await consolidator.consolidate(
                            messages: Array(recent),
                            using: backend,
                            config: agent.configuration.generationConfig,
                            into: mem,
                            layer: .working,
                            sessionId: sid
                        )) ?? []
                        if !keys.isEmpty {
                            continuation.yield(.memoryUpdated(keys: keys))
                        }
                    }
                }

                return
            }

            if let delegate = approvalDelegate {
                // Sequential execution — approval checks require user interaction in order.
                for call in response.toolCalls {
                    continuation.yield(.toolCallPending(id: call.id, name: call.name, arguments: call.arguments))
                    let approved = await delegate.shouldExecute(
                        toolName: call.name, callId: call.id, arguments: call.arguments
                    )
                    if !approved {
                        continuation.yield(.toolCallDenied(id: call.id, name: call.name))
                        messages.append(Message(
                            role: .tool,
                            content: "Tool call denied by user.",
                            toolCallId: call.id
                        ))
                        continue
                    }
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
            } else {
                // Parallel execution — emit starts upfront, run tools concurrently,
                // then emit results in original call order.
                for call in response.toolCalls {
                    continuation.yield(.toolCallStart(id: call.id, name: call.name))
                }
                typealias IndexedResult = (index: Int, call: ToolCallRequest, result: ToolResult)
                let toolRegistry = agent.toolRegistry
                var collectedResults: [IndexedResult] = []
                try await withThrowingTaskGroup(of: IndexedResult.self) { group in
                    for (index, call) in response.toolCalls.enumerated() {
                        group.addTask {
                            let result = try await toolRegistry.execute(
                                name: call.name, arguments: call.arguments
                            )
                            return (index, call, result)
                        }
                    }
                    for try await r in group {
                        collectedResults.append(r)
                    }
                }
                let ordered = collectedResults.sorted { $0.index < $1.index }
                for (_, call, result) in ordered {
                    continuation.yield(.toolResult(id: call.id, result))
                    messages.append(Message(
                        role: .tool,
                        content: result.content,
                        toolCallId: call.id
                    ))
                }
            }
        }

        continuation.yield(.turn(lastResponse))
        continuation.yield(.warning("Exceeded max tool round-trips (\(config.maxToolRoundTrips))"))
        continuation.yield(.done)
    }

    private func setRunning(_ value: Bool) {
        isRunning = value
    }

    /// Strip tool-call XML blocks from a text chunk (Qwen3.5 text-injection format).
    private func stripToolCallXML(_ text: String) -> String {
        var result = text
        if result.contains("<tool_call>") {
            result = result.replacingOccurrences(
                of: "<tool_call>[\\s\\S]*?</tool_call>", with: "", options: .regularExpression
            )
        }
        if result.contains("<function=") {
            result = result.replacingOccurrences(
                of: "<function=[\\s\\S]*?</function>", with: "", options: .regularExpression
            )
        }
        return result
    }

    /// End the session: promote working memories to long-term, clear working layer, cancel background tasks,
    /// and stop all monitored processes.
    public func endSession() async {
        // Shutdown all monitored processes
        await processMonitor?.shutdown()

        guard let mem = memory, sessionId != nil, config.memoryEnabled else { return }
        // Promote working memories to long-term
        let workingEntries = await mem.allEntries(layer: .working)
        if !workingEntries.isEmpty {
            let keys = workingEntries.map { $0.key }
            try? await mem.promote(keys: keys)
        }
        // Clear working layer
        try? await mem.clearLayer(.working)
        // Shutdown (cancel background embedding tasks)
        await mem.shutdown()
    }

    /// Current conversation history (read-only snapshot).
    public var conversationHistory: [Message] {
        messages
    }

    /// Rewinds the conversation to just before the most recent user turn,
    /// dropping that user message along with any assistant/tool messages
    /// that followed it. Returns the dropped user content so callers can
    /// re-submit it (regenerate flow). Returns nil if there is no user
    /// message to rewind past, or if a generation is currently in flight.
    public func rewindToPriorUser() -> String? {
        guard !isRunning else { return nil }
        guard let lastUserIdx = messages.lastIndex(where: { $0.role == .user }) else {
            return nil
        }
        let content = messages[lastUserIdx].content
        messages.removeSubrange(lastUserIdx...)
        return content
    }
}
