import Foundation
import Observation
import SwiftUI
import SwiftClawCore
import SwiftClawHTTP
import SwiftClawMLX
import SwiftClawTools
import SwiftClawPippin
import SwiftClawUI

// MARK: - ChatViewModel

@Observable
@MainActor
final class ChatViewModel {

    // MARK: Sidebar / session list
    var sessions: [SessionSummary] = []
    var selectedSessionId: String? = nil

    // MARK: Active chat
    var messages: [ChatBubble] = []
    var inputText: String = ""
    var isGenerating: Bool = false
    var streamingContentVersion: Int = 0
    var backendState: BackendState = .idle
    var errorMessage: String? = nil

    // MARK: Backend settings (persisted via AppStorage wrappers)
    var backendType: BackendType = .http
    var modelId: String = "mlx-community/Qwen3.5-9B-MLX-4bit"
    var httpURL: String = "http://localhost:11434/v1"
    var httpAPIKey: String = ""
    var temperature: Double = 0.7
    var maxTokens: Int = 4096

    // MARK: Adapter settings
    var adapters: [AdapterMetadata] = []
    var selectedAdapter: String? = nil
    var autoAdapter: Bool = false

    // MARK: Memory settings
    var memoryEnabled: Bool = false

    // MARK: Tool approval
    var toolApprovalOverrides: [String: Bool] = [:]
    private var pendingApproval: (callId: String, continuation: CheckedContinuation<Bool, Never>)? = nil

    // MARK: Private state
    private var session: Session? = nil
    private var backend: (any ModelBackend)? = nil
    private let store: FileSessionStore
    private var generationTask: Task<Void, Never>? = nil
    private var currentMetadata: SessionMetadata? = nil
    private var agentMemory: AgentMemory? = nil

    init() {
        // FileSessionStore.init can throw only on directory creation failure;
        // treat that as a non-fatal startup issue.
        if let s = (try? FileSessionStore()) ?? (try? FileSessionStore(baseDir: URL(fileURLWithPath: NSTemporaryDirectory()))) {
            self.store = s
        } else {
            fatalError("Cannot create FileSessionStore: both default and temp-dir attempts failed")
        }
        Task {
            await refreshSessions()
            await refreshAdapters()
        }
    }

    // MARK: - Backend Loading

    func loadBackend() async {
        if case .loading = backendState { return }
        guard backendState != .ready else { return }
        backendState = .loading(0)

        do {
            switch backendType {
            case .mlx:
                let modelIdCopy = modelId
                let adapterURL = resolveAdapterURL()
                let loaded = try await loadMLXBackend(modelId: modelIdCopy, adapterPath: adapterURL) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.backendState = .loading(progress)
                    }
                }
                backend = loaded
                backendState = .ready

            case .http:
                guard let url = URL(string: httpURL) else {
                    backendState = .error("Invalid URL: \(httpURL)")
                    return
                }
                let httpModel = modelId == "mlx-community/Qwen3.5-9B-MLX-4bit" ? "qwen2.5:7b" : modelId
                backend = HTTPBackend(
                    baseURL: url,
                    model: httpModel,
                    apiKey: httpAPIKey.isEmpty ? nil : httpAPIKey
                )
                backendState = .ready
            }
        } catch {
            backendState = .error(error.localizedDescription)
        }
    }

    // MARK: - Chat

    func newChat() async {
        generationTask?.cancel()
        generationTask = nil
        messages = []
        selectedSessionId = nil

        if backendState != .ready {
            await loadBackend()
        }
        guard let backend else { return }

        let sessionId = UUID().uuidString
        let config = (try? SwiftClawConfig.load()) ?? .default
        let tools: [any SwiftClawTool] = SwiftClawToolFactory.allTools(config: config) + PippinToolFactory.allTools()
        let agentConfig = AgentConfiguration(
            name: "SysopAgent",
            systemPrompt: """
                You are Sysop, a macOS assistant. You have access to tools for system administration, \
                file operations (sandboxed), environment inspection, and optionally pippin CLI wrappers \
                for Apple Mail and Voice Memos. Be concise and accurate.
                """,
            tools: tools,
            modelId: modelId,
            generationConfig: GenerationConfig(temperature: Float(temperature), maxTokens: maxTokens)
        )
        let agent = Agent(configuration: agentConfig)
        agentMemory = memoryEnabled ? (try? AgentMemory(namespace: "SysopAgent")) : nil
        var sessionConfig = SessionConfiguration()
        sessionConfig.memoryEnabled = memoryEnabled
        if toolApprovalOverrides.isEmpty {
            for tool in tools {
                toolApprovalOverrides[tool.name] = tool.requiresConfirmation
            }
        }
        session = Session(
            agent: agent,
            backend: backend,
            config: sessionConfig,
            sessionId: sessionId,
            memory: agentMemory,
            approvalDelegate: makeApprovalDelegate()
        )
        currentMetadata = SessionMetadata(agentName: agentConfig.name, modelId: modelId)
        selectedSessionId = sessionId
    }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }
        inputText = ""

        guard session != nil else {
            generationTask = Task {
                await newChat()
                await doSend(text)
            }
            return
        }

        generationTask = Task { await doSend(text) }
    }

    func cancelGeneration() {
        if let pending = pendingApproval {
            pendingApproval = nil
            pending.continuation.resume(returning: false)
        }
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    func approveToolCall(callId: String) {
        guard let pending = pendingApproval, pending.callId == callId else { return }
        pendingApproval = nil
        pending.continuation.resume(returning: true)
    }

    func denyToolCall(callId: String) {
        guard let pending = pendingApproval, pending.callId == callId else { return }
        pendingApproval = nil
        pending.continuation.resume(returning: false)
    }

    func makeApprovalDelegate() -> any ToolApprovalDelegate {
        return UIToolApprovalDelegate { [weak self] toolName, callId, _ in
            guard let self else { return false }
            let needsApproval = await MainActor.run { self.toolApprovalOverrides[toolName] ?? false }
            if !needsApproval { return true }
            return await withCheckedContinuation { cont in
                Task { @MainActor [weak self] in
                    self?.pendingApproval = (callId, cont)
                }
            }
        }
    }

    // MARK: - Session Management

    func selectSession(id: String) async {
        guard id != selectedSessionId else { return }
        generationTask?.cancel()
        generationTask = nil
        messages = []
        selectedSessionId = id

        do {
            let restored = try await store.load(sessionId: id)
            if backendState != .ready { await loadBackend() }
            guard let backend else { return }

            let config = (try? SwiftClawConfig.load()) ?? .default
            let tools: [any SwiftClawTool] = SwiftClawToolFactory.allTools(config: config) + PippinToolFactory.allTools()
            let agentConfig = AgentConfiguration(
                name: restored.metadata.agentName,
                systemPrompt: "You are Sysop, a macOS assistant.",
                tools: tools,
                modelId: restored.metadata.modelId,
                generationConfig: GenerationConfig(temperature: Float(temperature), maxTokens: maxTokens)
            )
            let agent = Agent(configuration: agentConfig)
            agentMemory = memoryEnabled ? (try? AgentMemory(namespace: "SysopAgent")) : nil
            var sessionConfig = SessionConfiguration()
            sessionConfig.memoryEnabled = memoryEnabled
            if toolApprovalOverrides.isEmpty {
                for tool in tools {
                    toolApprovalOverrides[tool.name] = tool.requiresConfirmation
                }
            }
            session = Session(
                agent: agent,
                backend: backend,
                config: sessionConfig,
                sessionId: id,
                restoredMessages: restored.messages,
                memory: agentMemory,
                approvalDelegate: makeApprovalDelegate()
            )
            currentMetadata = restored.metadata
            rebuildBubbles(from: restored.messages)
        } catch {
            errorMessage = "Failed to load session: \(error.localizedDescription)"
        }
    }

    func deleteSession(id: String) async {
        do {
            try await store.delete(sessionId: id)
            if selectedSessionId == id {
                selectedSessionId = nil
                session = nil
                messages = []
            }
            await refreshSessions()
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    func refreshSessions() async {
        sessions = (try? await store.list()) ?? []
    }

    func refreshAdapters() async {
        adapters = (try? AdapterStore().list()) ?? []
    }

    // MARK: - Private Helpers

    private func resolveAdapterURL() -> URL? {
        if autoAdapter {
            let store = (try? AdapterStore())
            let all = (try? store?.list()) ?? []
            if let selected = AdapterSelector().select(prompt: "", from: all, forModel: modelId),
               let url = try? store?.adapterURL(name: selected.name) {
                return url
            }
            return nil
        }
        if let name = selectedAdapter, let store = try? AdapterStore() {
            return try? store.adapterURL(name: name)
        }
        return nil
    }

    private func doSend(_ text: String) async {
        guard let agentSession = session else { return }
        isGenerating = true
        messages.append(ChatBubble(kind: .user(text)))

        // Streaming bubble state (reset per agentic round)
        var streamingBubbleId: UUID? = nil
        var currentText = ""
        var currentThinking: String? = nil

        func ensureStreamingBubble() {
            if streamingBubbleId == nil {
                let id = UUID()
                streamingBubbleId = id
                messages.append(ChatBubble(id: id, kind: .streamingAssistant(text: "", thinking: nil, isStreaming: true)))
            }
        }

        func updateStreamingBubble() {
            guard let id = streamingBubbleId,
                  let idx = messages.lastIndex(where: { $0.id == id }) else { return }
            messages[idx] = ChatBubble(id: id, kind: .streamingAssistant(
                text: currentText, thinking: currentThinking, isStreaming: true
            ))
            streamingContentVersion += 1
        }

        func finalizeStreamingBubble(response: GenerationResponse) {
            guard let id = streamingBubbleId,
                  let idx = messages.lastIndex(where: { $0.id == id }) else { return }
            let finalText = currentText.isEmpty ? response.content : currentText
            if finalText.isEmpty && response.toolCalls.isEmpty {
                messages.remove(at: idx)
            } else if currentThinking != nil {
                // Keep streaming variant so collapsible thinking section stays visible
                messages[idx] = ChatBubble(id: id, kind: .streamingAssistant(
                    text: finalText, thinking: currentThinking, isStreaming: false
                ))
            } else {
                messages[idx] = ChatBubble(id: id, kind: .assistant(finalText))
            }
        }

        do {
            let stream = await agentSession.respond(to: text)
            for try await event in stream {
                if Task.isCancelled { break }
                switch event {
                case let .textDelta(delta):
                    currentText += delta
                    ensureStreamingBubble()
                    updateStreamingBubble()

                case let .thinkingDelta(delta):
                    currentThinking = (currentThinking ?? "") + delta
                    ensureStreamingBubble()
                    updateStreamingBubble()

                case let .toolCallPending(id, name, arguments):
                    messages.append(ChatBubble(kind: .toolCallPending(name: name, arguments: arguments, callId: id)))

                case let .toolCallDenied(id, name):
                    if let idx = messages.lastIndex(where: {
                        if case let .toolCallPending(_, _, cid) = $0.kind { return cid == id }
                        return false
                    }) {
                        messages[idx] = ChatBubble(kind: .toolCallDenied(name: name, callId: id))
                    } else {
                        messages.append(ChatBubble(kind: .toolCallDenied(name: name, callId: id)))
                    }

                case let .toolCallStart(id, name):
                    if let idx = messages.lastIndex(where: {
                        if case let .toolCallPending(_, _, cid) = $0.kind { return cid == id }
                        return false
                    }) {
                        messages[idx] = ChatBubble(kind: .toolCall(name: name, callId: id))
                    } else {
                        messages.append(ChatBubble(kind: .toolCall(name: name, callId: id)))
                    }

                case let .toolResult(id, result):
                    messages.append(ChatBubble(kind: .toolResult(
                        content: result.content, isError: result.isError, callId: id
                    )))

                case let .turn(response):
                    finalizeStreamingBubble(response: response)
                    // Reset streaming state for the next agentic round (tool calls may trigger more)
                    streamingBubbleId = nil
                    currentText = ""
                    currentThinking = nil

                case let .warning(msg):
                    messages.append(ChatBubble(kind: .warning(msg)))

                case let .memoryUpdated(keys):
                    messages.append(ChatBubble(kind: .warning("Memory updated: \(keys.joined(separator: ", "))")))

                case .done:
                    // Finalize any streaming bubble that never got a .turn (e.g. cancelled mid-stream)
                    if let id = streamingBubbleId,
                       let idx = messages.lastIndex(where: { $0.id == id }) {
                        if currentText.isEmpty && currentThinking == nil {
                            messages.remove(at: idx)
                        } else if currentThinking != nil {
                            messages[idx] = ChatBubble(id: id, kind: .streamingAssistant(
                                text: currentText, thinking: currentThinking, isStreaming: false
                            ))
                        } else {
                            messages[idx] = ChatBubble(id: id, kind: .assistant(currentText))
                        }
                    }
                }
            }
            // Auto-save after each turn (skip if cancelled)
            if !Task.isCancelled, let meta = currentMetadata {
                try? await agentSession.save(to: store, metadata: meta)
                await refreshSessions()
            }
        } catch {
            // Finalize any open streaming bubble before showing error
            if let id = streamingBubbleId,
               let idx = messages.lastIndex(where: { $0.id == id }) {
                if currentText.isEmpty && currentThinking == nil {
                    messages.remove(at: idx)
                } else {
                    messages[idx] = ChatBubble(id: id, kind: .assistant(currentText))
                }
            }
            if !Task.isCancelled {
                messages.append(ChatBubble(kind: .warning("Error: \(error.localizedDescription)")))
            }
        }

        isGenerating = false
    }

    private func rebuildBubbles(from msgs: [Message]) {
        var bubbles: [ChatBubble] = []
        for msg in msgs {
            switch msg.role {
            case .system:
                break
            case .user:
                bubbles.append(ChatBubble(kind: .user(msg.content)))
            case .assistant:
                if !msg.content.isEmpty {
                    bubbles.append(ChatBubble(kind: .assistant(msg.content)))
                }
                for call in msg.toolCalls ?? [] {
                    bubbles.append(ChatBubble(kind: .toolCall(name: call.name, callId: call.id)))
                }
            case .tool:
                bubbles.append(ChatBubble(kind: .toolResult(
                    content: msg.content,
                    isError: false,
                    callId: msg.toolCallId ?? ""
                )))
            }
        }
        messages = bubbles
    }
}
