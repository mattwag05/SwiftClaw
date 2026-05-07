import Foundation

extension Session {
    /// XML-protocol agentic loop.
    ///
    /// Called from `respond(to:)` when `backend.preferredToolProtocol == .xml`.
    /// Unlike the JSON path, tool definitions are injected into the system prompt
    /// as prose; `generate()` is called with an empty tools array. The model's
    /// text output is scanned for `<action>` blocks which are dispatched through
    /// the same `ToolRegistry` as the JSON path.
    func runXMLLoop(
        prompt: String,
        agent: Agent,
        backend: any ModelBackend,
        config: SessionConfiguration,
        approvalDelegate: (any ToolApprovalDelegate)?,
        continuation: AsyncThrowingStream<SessionEvent, Error>.Continuation
    ) async throws {
        let parser = XMLActionParser()
        let formatter = XMLActionFormatter()

        // 1. Memory injection (mirrors the JSON runLoop exactly).
        if config.memoryEnabled, let mem = memory {
            let basePrompt = agent.configuration.systemPrompt
            if !messages.isEmpty {
                messages[0] = Message(role: .system, content: basePrompt)
            }
            let relevant = (try? await mem.search(query: prompt, layer: nil, topK: config.retrievalTopK)) ?? []
            let filtered = relevant.filter { $0.score >= config.retrievalThreshold }
            if !filtered.isEmpty {
                let factsText = filtered.map { "- \($0.entry.key): \($0.entry.content)" }.joined(separator: "\n")
                let enriched = basePrompt + "\n\n## Relevant Memories\n" + factsText
                if !messages.isEmpty {
                    messages[0] = Message(role: .system, content: enriched)
                }
            }
        }

        // 2. Append XML tool-use block to system message (once — stays for all rounds).
        let xmlBlock = formatter.formatToolBlock(tools: agent.toolRegistry.definitions)
        if !xmlBlock.isEmpty, !messages.isEmpty {
            messages[0] = Message(role: .system, content: messages[0].content + xmlBlock)
        }

        // 3. Append user message.
        messages.append(Message(role: .user, content: prompt))

        // 4. Context compression (mirrors the JSON runLoop).
        if let threshold = config.compressionTokenThreshold,
           compressor.estimateTokens(messages) > threshold
        {
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
                    if !keys.isEmpty { continuation.yield(.memoryUpdated(keys: keys)) }
                }
            }
            let compressed = (try? await compressor.compress(
                messages,
                using: backend,
                config: agent.configuration.generationConfig,
                keepRecent: config.compressionKeepRecent
            )) ?? messages
            messages = compressed
            continuation.yield(.warning("Context compressed — older messages summarized"))
        }

        // 5. Hard trim (fallback overflow guard).
        if messages.count > config.maxTotalMessages {
            let keepCount = max(1, config.maxTotalMessages - 1)
            var trimmed = Array(messages.dropFirst().suffix(keepCount))
            while trimmed.count > 1, trimmed.first?.role == .tool {
                trimmed.removeFirst()
            }
            messages = [messages[0]] + trimmed
        }

        // 6. XML agentic loop.
        var lastDisplayText = ""

        for _ in 0 ..< config.maxToolRoundTrips {
            // Buffers for this round.
            var thinkBuffer: [String] = []
            var sawThinkEnd = false
            var actionBuffer = ""   // Post-think text, scanned for <action> blocks
            var fullText = ""       // Complete model output including action blocks
            var displayText = ""    // User-visible text (no action blocks)
            var pendingActions: [ParsedXMLAction] = []

            let stream: AsyncThrowingStream<StreamChunk, Error> = backend.generate(
                messages: messages,
                tools: [],   // XML mode: tool descriptions are already in the system prompt
                config: agent.configuration.generationConfig
            )

            for try await chunk in stream {
                // Dedicated reasoning field (Gemma 4, DeepSeek-R1 etc.).
                if let thinking = chunk.thinking, !thinking.isEmpty {
                    continuation.yield(.thinkingDelta(thinking))
                }

                guard let text = chunk.text else { continue }
                fullText += text

                if sawThinkEnd {
                    actionBuffer += text
                } else {
                    thinkBuffer.append(text)
                    let combined = thinkBuffer.joined()
                    if let thinkEndRange = combined.range(of: "</think>") {
                        sawThinkEnd = true
                        let thinkPart = String(combined[..<thinkEndRange.lowerBound])
                            .replacingOccurrences(of: "<think>", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        actionBuffer = String(combined[thinkEndRange.upperBound...])
                        thinkBuffer = []
                        if !thinkPart.isEmpty {
                            continuation.yield(.thinkingDelta(thinkPart))
                        }
                    }
                }

                // Drain complete <action> blocks and emit safe text prefix.
                while let (before, action, after) = parser.findAction(in: actionBuffer) {
                    if !before.isEmpty {
                        continuation.yield(.textDelta(before))
                        displayText += before
                    }
                    pendingActions.append(action)
                    actionBuffer = after
                }
                let (safe, rest) = parser.safePrefix(of: actionBuffer)
                if !safe.isEmpty {
                    continuation.yield(.textDelta(safe))
                    displayText += safe
                }
                actionBuffer = rest
            }

            // After stream ends: flush think buffer if no </think> found.
            if !sawThinkEnd, !thinkBuffer.isEmpty {
                actionBuffer = thinkBuffer.joined()
            }

            // Final drain of actionBuffer.
            while let (before, action, after) = parser.findAction(in: actionBuffer) {
                if !before.isEmpty {
                    continuation.yield(.textDelta(before))
                    displayText += before
                }
                pendingActions.append(action)
                actionBuffer = after
            }
            if !actionBuffer.isEmpty {
                continuation.yield(.textDelta(actionBuffer))
                displayText += actionBuffer
            }

            let cleanDisplay = displayText.trimmingCharacters(in: .whitespacesAndNewlines)
            lastDisplayText = cleanDisplay

            // Append assistant message with the full model output.
            messages.append(Message(role: .assistant, content: fullText))

            if pendingActions.isEmpty {
                // No tool calls — turn is complete.
                let response = GenerationResponse(content: cleanDisplay, finishReason: .stop)
                continuation.yield(.turn(response))

                // Post-turn consolidation.
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
                        if !keys.isEmpty { continuation.yield(.memoryUpdated(keys: keys)) }
                    }
                }

                continuation.yield(.done)
                return
            }

            // Dispatch tool calls.
            if let delegate = approvalDelegate {
                // Sequential execution with approval gating.
                for action in pendingActions {
                    let callId = UUID().uuidString
                    continuation.yield(.toolCallPending(
                        id: callId, name: action.name, arguments: action.arguments
                    ))
                    let approved = await delegate.shouldExecute(
                        toolName: action.name, callId: callId, arguments: action.arguments
                    )
                    guard approved else {
                        continuation.yield(.toolCallDenied(id: callId, name: action.name))
                        messages.append(Message(
                            role: .tool,
                            content: "[denied] \(action.name): Tool call denied by user."
                        ))
                        continue
                    }
                    continuation.yield(.toolCallStart(id: callId, name: action.name))
                    let result: ToolResult
                    do {
                        result = try await agent.toolRegistry.execute(
                            name: action.name, arguments: action.arguments
                        )
                    } catch {
                        result = ToolResult.failure(error.localizedDescription)
                    }
                    let prefix = result.isError ? "[error]" : "[ok]"
                    continuation.yield(.toolResult(id: callId, result))
                    messages.append(Message(
                        role: .tool,
                        content: "\(prefix) \(action.name): \(result.content)"
                    ))
                }
            } else {
                // Parallel execution — emit starts upfront, collect results concurrently.
                let callIds = pendingActions.map { _ in UUID().uuidString }
                for (action, callId) in zip(pendingActions, callIds) {
                    continuation.yield(.toolCallStart(id: callId, name: action.name))
                }

                typealias IndexedResult = (index: Int, callId: String, action: ParsedXMLAction, result: ToolResult)
                let toolRegistry = agent.toolRegistry
                var collectedResults: [IndexedResult] = []
                try await withThrowingTaskGroup(of: IndexedResult.self) { group in
                    for (index, (action, callId)) in zip(pendingActions, callIds).enumerated() {
                        group.addTask {
                            let result = try await toolRegistry.execute(
                                name: action.name, arguments: action.arguments
                            )
                            return (index, callId, action, result)
                        }
                    }
                    for try await r in group {
                        collectedResults.append(r)
                    }
                }

                let ordered = collectedResults.sorted { $0.index < $1.index }
                for (_, callId, action, result) in ordered {
                    let prefix = result.isError ? "[error]" : "[ok]"
                    continuation.yield(.toolResult(id: callId, result))
                    messages.append(Message(
                        role: .tool,
                        content: "\(prefix) \(action.name): \(result.content)"
                    ))
                }
            }
        }

        // Exceeded max round-trips.
        let response = GenerationResponse(content: lastDisplayText, finishReason: .stop)
        continuation.yield(.turn(response))
        continuation.yield(.warning("Exceeded max tool round-trips (\(config.maxToolRoundTrips))"))
        continuation.yield(.done)
    }
}
