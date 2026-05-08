import AppKit
import Foundation
import Observation
import SwiftClawCore
import SwiftClawHTTP
import SwiftClawMemory
import SwiftClawMLX
import SwiftClawPippin
import SwiftClawSkills
import SwiftClawTools
import SwiftClawUI
import SwiftUI

// MARK: - ChatViewModel

@Observable
@MainActor
final class ChatViewModel {
    // MARK: Sidebar / session list

    var sessions: [SessionSummary] = [] {
        didSet { rebuildGroupedSessions() }
    }

    var groupedSessions: [SessionGroup] = []
    var selectedSessionId: String?
    var sessionSearch: String = "" {
        didSet { rebuildGroupedSessions() }
    }

    var folders: [Folder] = [] {
        didSet { rebuildGroupedSessions() }
    }

    var groupingMode: GroupingMode = .time {
        didSet { rebuildGroupedSessions() }
    }

    // MARK: Active chat

    var messages: [ChatBubble] = []
    var inputText: String = ""
    var isGenerating: Bool = false
    var streamingContentVersion: Int = 0
    var backendState: BackendState = .idle
    var errorMessage: String?
    var lastTokenUsage: TokenUsage?

    // MARK: Backend settings — persisted to UserDefaults via didSet

    /// @AppStorage is incompatible with @Observable; stored properties with didSet are the correct pattern.
    var backendType: BackendType = .http {
        didSet { UserDefaults.standard.set(backendType.rawValue, forKey: "sc.backendType") }
    }

    var modelId: String = "mlx-community/Qwen3.5-9B-MLX-4bit" {
        didSet { UserDefaults.standard.set(modelId, forKey: "sc.modelId") }
    }

    var httpURL: String = "http://localhost:11434/v1" {
        didSet { UserDefaults.standard.set(httpURL, forKey: "sc.httpURL") }
    }

    var httpAPIKey: String = "" {
        didSet { UserDefaults.standard.set(httpAPIKey, forKey: "sc.httpAPIKey") }
    }

    var temperature: Double = 0.7 {
        didSet { UserDefaults.standard.set(temperature, forKey: "sc.temperature") }
    }

    var maxTokens: Int = 4096 {
        didSet { UserDefaults.standard.set(maxTokens, forKey: "sc.maxTokens") }
    }

    // MARK: Model discovery

    var availableModels: [DiscoveredModel] = []
    var selectedModelInfo: ModelInfo?
    var isDiscoveringModels: Bool = false

    /// Dynamic context window reported by the backend for `modelId`; falls
    /// back to the static `ModelCapabilities` table when unknown.
    var discoveredContextWindow: Int? {
        selectedModelInfo?.contextLength
    }

    // MARK: Adapter settings

    var adapters: [AdapterMetadata] = []
    var selectedAdapter: String?
    var autoAdapter: Bool = false {
        didSet { UserDefaults.standard.set(autoAdapter, forKey: "sc.autoAdapter") }
    }

    // MARK: Memory settings

    var memoryEnabled: Bool = false {
        didSet { UserDefaults.standard.set(memoryEnabled, forKey: "sc.memoryEnabled") }
    }

    enum EmbeddingState: Equatable {
        case idle
        case loading(Double)
        case ready
        case unavailable
    }

    var embeddingState: EmbeddingState = .idle

    // MARK: Build mode + Canvas

    /// The mode of the currently selected session.
    var sessionMode: SessionMode = .chat

    /// Whether the Canvas pane is open (Build mode only).
    var canvasOpen: Bool = false

    /// HSplitView divider position (0.0–1.0). Persisted per-session.
    var canvasSplit: Double = 0.5

    /// The file being written right now (for the Code tab live view).
    var currentlyWritingFile: (path: String, partial: String)?

    /// Last file path written — Canvas observes this to trigger preview reload.
    var canvasFileWrittenPath: String?

    // MARK: Tool approval

    var toolApprovalOverrides: [String: Bool] = [:]
    private var pendingApproval: (callId: String, continuation: CheckedContinuation<Bool, Never>)?

    // MARK: Private state

    private var session: Session?
    private var backend: (any ModelBackend)?
    private let store: FileSessionStore
    private let folderStore: FolderStore?
    private var generationTask: Task<Void, Never>?
    private var currentMetadata: SessionMetadata?
    private var agentMemory: (any MemoryProvider)?
    let workspaceManager: WorkspaceManager = {
        if let wm = (try? WorkspaceManager()) ?? (try? WorkspaceManager(baseDir: URL(fileURLWithPath: NSTemporaryDirectory()))) {
            return wm
        }
        fatalError("Cannot create WorkspaceManager: both default and temp-dir attempts failed")
    }()

    init() {
        // FileSessionStore.init can throw only on directory creation failure;
        // treat that as a non-fatal startup issue.
        if let s = (try? FileSessionStore()) ?? (try? FileSessionStore(baseDir: URL(fileURLWithPath: NSTemporaryDirectory()))) {
            store = s
        } else {
            fatalError("Cannot create FileSessionStore: both default and temp-dir attempts failed")
        }
        folderStore = try? FolderStore()
        // Restore persisted settings
        let ud = UserDefaults.standard
        if let raw = ud.string(forKey: "sc.backendType"), let bt = BackendType(rawValue: raw) { backendType = bt }
        if let s = ud.string(forKey: "sc.modelId") { modelId = s }
        if let s = ud.string(forKey: "sc.httpURL") { httpURL = s }
        if let s = ud.string(forKey: "sc.httpAPIKey") { httpAPIKey = s }
        let savedTemp = ud.double(forKey: "sc.temperature")
        if savedTemp != 0 { temperature = savedTemp }
        let savedTokens = ud.integer(forKey: "sc.maxTokens")
        if savedTokens != 0 { maxTokens = savedTokens }
        autoAdapter = ud.bool(forKey: "sc.autoAdapter")
        memoryEnabled = ud.bool(forKey: "sc.memoryEnabled")

        Task {
            await refreshSessions()
            await refreshFolders()
            await refreshAdapters()
            await discoverModels()
            // Pre-warm the backend so the first message doesn't pay the full
            // load latency. HTTP backend init is cheap; MLX backend will
            // surface a loading overlay during weight load.
            if backendType == .http, backendState == .idle {
                await loadBackend()
            }
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
                Task { await discoverModels() }

            case .http:
                guard URL(string: httpURL) != nil else {
                    backendState = .error("Invalid URL: \(httpURL)")
                    return
                }
                let httpModel = modelId == "mlx-community/Qwen3.5-9B-MLX-4bit" ? "gemma4:latest" : modelId
                rebuildHTTPBackend(model: httpModel)
                backendState = .ready
                Task { await discoverModels() }
            }
        } catch {
            backendState = .error(error.localizedDescription)
        }
    }

    // MARK: - Chat

    func newChat() async {
        if let pending = pendingApproval {
            pendingApproval = nil
            pending.continuation.resume(returning: false)
        }
        generationTask?.cancel()
        generationTask = nil
        messages = []
        selectedSessionId = nil
        lastTokenUsage = nil

        if backendState != .ready {
            await loadBackend()
        }
        guard let backend else { return }

        let sessionId = UUID().uuidString
        let config = (try? SwiftClawConfig.load()) ?? .default
        agentMemory = memoryEnabled ? makeMemoryStore(config: config) : nil
        var tools: [any SwiftClawTool] = SwiftClawToolFactory.allTools(config: config) + PippinToolFactory.allTools()
        if let memStore = agentMemory {
            tools += MemoryToolFactory.allTools(store: memStore)
        }
        var basePrompt = await buildBasePrompt(mode: sessionMode, sessionId: sessionId)
        await applySkills(config: config, tools: &tools, prompt: &basePrompt)
        let agentConfig = AgentConfiguration(
            name: "SysopAgent",
            systemPrompt: basePrompt,
            tools: tools,
            modelId: modelId,
            generationConfig: GenerationConfig(temperature: Float(temperature), maxTokens: maxTokens),
            credentialProxy: config.makeCredentialProxy()
        )
        let agent = Agent(configuration: agentConfig)
        var sessionConfig = SessionConfiguration()
        sessionConfig.memoryEnabled = memoryEnabled
        sessionConfig.retrievalTopK = config.retrievalTopK
        sessionConfig.retrievalThreshold = config.retrievalThreshold
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
        currentMetadata = SessionMetadata(
            agentName: agentConfig.name,
            modelId: modelId,
            mode: sessionMode
        )
        selectedSessionId = sessionId
    }

    func sendSuggestion(_ text: String) {
        inputText = text
        send()
    }

    func send() {
        let raw = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, !isGenerating else { return }
        inputText = ""

        // Per-message hints inferred from the composer's chip state.
        let webContext = UserDefaults.standard.bool(forKey: "sc.composerWebContext")
        let prelude = webContext
            ? "(Web context requested — please consult a web search tool if available.)\n\n"
            : ""
        let text = prelude + raw

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

    // MARK: - Message Actions

    @discardableResult
    func copyBubble(_ bubble: ChatBubble) -> String {
        guard let text = bubble.kind.fullText, !text.isEmpty else { return "" }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        return text
    }

    /// Rewind to just before the most recent user turn and re-submit it.
    /// No-ops if a generation is in flight or no prior user turn exists.
    /// `isGenerating` is set synchronously before the task spawns so a fast
    /// second click (or concurrent Send) can't drop a second user turn; the
    /// session id is snapshotted so a mid-flight session switch aborts the
    /// resubmit rather than mutating the new session's bubble array.
    ///
    /// The visible transcript is only truncated AFTER confirming the session
    /// was actually rewound (`prompt != nil`) and the selection still matches
    /// — otherwise a failed rewind would drop UI history without a matching
    /// session-state change. `isGenerating` stays `true` through the handoff
    /// to `doSend`, so a concurrent Send/regenerate click can't slip in
    /// during the gap.
    func regenerate() {
        guard !isGenerating, let agentSession = session else { return }
        let sessionIdSnapshot = selectedSessionId
        isGenerating = true
        generationTask = Task { [weak self] in
            guard let self else { return }
            let rewoundPrompt = await agentSession.rewindToPriorUser()
            let prompt: String? = await MainActor.run {
                guard let rewoundPrompt, self.selectedSessionId == sessionIdSnapshot else {
                    self.isGenerating = false
                    return nil
                }
                if let lastUser = self.messages.lastIndex(where: {
                    if case .user = $0.kind { return true }
                    return false
                }) {
                    self.messages.removeSubrange(lastUser...)
                }
                return rewoundPrompt
            }
            guard let prompt else { return }
            // doSend owns isGenerating through the resubmission; leaving it
            // true across the hand-off blocks a concurrent Send/regenerate.
            await self.doSend(prompt)
        }
    }

    // MARK: - Session Management

    func selectSession(id: String) async {
        guard id != selectedSessionId else { return }
        // Resume any pending approval before switching — avoids leaking a suspended continuation.
        if let pending = pendingApproval {
            pendingApproval = nil
            pending.continuation.resume(returning: false)
        }
        generationTask?.cancel()
        generationTask = nil
        messages = []
        selectedSessionId = id
        lastTokenUsage = nil

        do {
            let restored = try await store.load(sessionId: id)
            if backendState != .ready { await loadBackend() }
            guard let backend else { return }

            let config = (try? SwiftClawConfig.load()) ?? .default
            agentMemory = memoryEnabled ? makeMemoryStore(config: config) : nil
            var tools: [any SwiftClawTool] = SwiftClawToolFactory.allTools(config: config) + PippinToolFactory.allTools()
            if let memStore = agentMemory {
                tools += MemoryToolFactory.allTools(store: memStore)
            }
            let restoredMode = restored.metadata.mode
            var basePrompt = await buildBasePrompt(
                mode: restoredMode,
                sessionId: id,
                systemPromptOverride: restored.metadata.systemPromptOverride
            )
            await applySkills(config: config, tools: &tools, prompt: &basePrompt)
            let agentConfig = AgentConfiguration(
                name: restored.metadata.agentName,
                systemPrompt: basePrompt,
                tools: tools,
                modelId: restored.metadata.modelId,
                generationConfig: GenerationConfig(temperature: Float(temperature), maxTokens: maxTokens),
                credentialProxy: config.makeCredentialProxy()
            )
            let agent = Agent(configuration: agentConfig)
            var sessionConfig = SessionConfiguration()
            sessionConfig.memoryEnabled = memoryEnabled
            sessionConfig.retrievalTopK = config.retrievalTopK
            sessionConfig.retrievalThreshold = config.retrievalThreshold
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
            sessionMode = restored.metadata.mode
            canvasSplit = restored.metadata.canvasSplit
            canvasOpen = false
            canvasFileWrittenPath = nil
            rebuildBubbles(from: restored.messages)
        } catch {
            errorMessage = "Failed to load session: \(error.localizedDescription)"
            // Roll back selection so the UI doesn't think it's "in" a broken session.
            selectedSessionId = nil
            session = nil
            currentMetadata = nil
        }
    }

    func deleteSession(id: String) async {
        do {
            try await store.delete(sessionId: id)
            if selectedSessionId == id {
                if let pending = pendingApproval {
                    pendingApproval = nil
                    pending.continuation.resume(returning: false)
                }
                generationTask?.cancel()
                generationTask = nil
                selectedSessionId = nil
                session = nil
                messages = []
                currentMetadata = nil
                lastTokenUsage = nil
            }
            await refreshSessions()
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    func refreshSessions() async {
        sessions = (try? await store.list()) ?? []
    }

    func refreshFolders() async {
        guard let folderStore else { return }
        folders = (try? await folderStore.list()) ?? []
    }

    // MARK: - Session organization

    func pinSession(id: String) async {
        do {
            try await store.updateMetadata(sessionId: id) { meta in
                meta.isPinned = true
                meta.pinnedAt = Date()
            }
            await refreshSessions()
        } catch {
            errorMessage = "Pin failed: \(error.localizedDescription)"
        }
    }

    func unpinSession(id: String) async {
        do {
            try await store.updateMetadata(sessionId: id) { meta in
                meta.isPinned = false
                meta.pinnedAt = nil
            }
            await refreshSessions()
        } catch {
            errorMessage = "Unpin failed: \(error.localizedDescription)"
        }
    }

    func renameSession(id: String, to title: String) async {
        do {
            try await store.updateMetadata(sessionId: id) { meta in
                meta.title = title.isEmpty ? nil : title
            }
            await refreshSessions()
        } catch {
            errorMessage = "Rename failed: \(error.localizedDescription)"
        }
    }

    func moveSession(id: String, toFolder folderID: UUID?) async {
        do {
            try await store.updateMetadata(sessionId: id) { meta in
                meta.folderID = folderID
            }
            await refreshSessions()
        } catch {
            errorMessage = "Move failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Folder management

    func createFolder(name: String) async {
        guard let folderStore, !name.isEmpty else { return }
        do {
            _ = try await folderStore.create(name: name)
            await refreshFolders()
        } catch {
            errorMessage = "Create folder failed: \(error.localizedDescription)"
        }
    }

    func renameFolder(id: UUID, to newName: String) async {
        guard let folderStore else { return }
        do {
            try await folderStore.rename(id: id, to: newName)
            await refreshFolders()
        } catch {
            errorMessage = "Rename folder failed: \(error.localizedDescription)"
        }
    }

    func deleteFolder(id: UUID) async {
        guard let folderStore else { return }
        do {
            try await folderStore.delete(id: id)
            // Unfile sessions that referenced this folder.
            for session in sessions where session.folderID == id {
                try? await store.updateMetadata(sessionId: session.sessionId) { meta in
                    meta.folderID = nil
                }
            }
            await refreshFolders()
            await refreshSessions()
        } catch {
            errorMessage = "Delete folder failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Grouping

    /// Filter by `sessionSearch` (case-insensitive match on title + preview)
    /// before handing to the grouper.
    private func rebuildGroupedSessions() {
        let query = sessionSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [SessionSummary]
        if query.isEmpty {
            filtered = sessions
        } else {
            filtered = sessions.filter { summary in
                if summary.displayTitle.lowercased().contains(query) { return true }
                if summary.preview.lowercased().contains(query) { return true }
                return false
            }
        }
        groupedSessions = SessionGrouper.group(filtered, mode: groupingMode, folders: folders)
    }

    func refreshAdapters() async {
        adapters = (try? AdapterStore().list()) ?? []
    }

    // MARK: - Model Discovery

    func discoverModels() async {
        // Coalesce rapid re-triggers (init + loadBackend + two settings `.task`s
        // can fire in the same window). Skip if a scan is already in flight.
        guard !isDiscoveringModels else { return }
        isDiscoveringModels = true
        defer { isDiscoveringModels = false }

        let service = ModelDiscoveryService()
        var models: [DiscoveredModel] = []

        switch backendType {
        case .http:
            guard let url = URL(string: httpURL) else { return }
            if let ollamaModels = try? await service.listOllamaModels(baseURL: url) {
                models = ollamaModels
            } else if let openAIModels = try? await service.listOpenAIModels(
                baseURL: url,
                apiKey: httpAPIKey.isEmpty ? nil : httpAPIKey
            ) {
                models = openAIModels
            }

        case .mlx:
            let scanner = MLXModelScanner()
            models = await scanner.listCachedModels()
        }

        // @Observable fires on every assignment regardless of value — guard so
        // a no-op scan doesn't re-render the model-list views.
        if models != availableModels {
            availableModels = models
        }
    }

    func fetchModelInfo(for modelName: String) async {
        selectedModelInfo = nil

        switch backendType {
        case .http:
            guard let url = URL(string: httpURL) else { return }
            let service = ModelDiscoveryService()
            if let info = try? await service.getOllamaModelInfo(baseURL: url, model: modelName) {
                selectedModelInfo = info
                if let defaultTemp = info.temperature {
                    temperature = defaultTemp
                }
            }

        case .mlx:
            let scanner = MLXModelScanner()
            if let info = await scanner.getModelInfo(modelId: modelName) {
                selectedModelInfo = info
            }
        }
    }

    func selectDiscoveredModel(_ model: DiscoveredModel) async {
        modelId = model.id
        await fetchModelInfo(for: model.id)
        // HTTP backend bakes the model ID at init time — rebuild it so the next
        // generation uses the chosen model rather than the original default.
        if backendType == .http {
            rebuildHTTPBackend(model: model.id)
        }
    }

    // MARK: - Private Helpers

    private func rebuildHTTPBackend(model: String) {
        guard let url = URL(string: httpURL) else { return }
        let config = (try? SwiftClawConfig.load()) ?? .default
        backend = HTTPBackend(
            baseURL: url,
            model: model,
            apiKey: httpAPIKey.isEmpty ? nil : httpAPIKey,
            cacheMode: config.cacheMode
        )
    }

    private func buildBasePrompt(mode: SessionMode, sessionId: String, systemPromptOverride: String? = nil) async -> String {
        let workspacePath: String? = mode == .build
            ? await workspaceManager.path(for: sessionId).path : nil
        return SystemPromptBuilder(
            mode: mode,
            workspacePath: workspacePath,
            sessionId: sessionId,
            systemPromptOverride: systemPromptOverride
        ).build(enableTools: true)
    }

    private func applySkills(config: SwiftClawConfig, tools: inout [any SwiftClawTool], prompt: inout String) async {
        guard config.skillsEnabled else { return }
        let dirURL = config.skillsDirectory.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
        let store = SkillStore(directory: dirURL)
        let skillList = await store.list()
        tools += SkillToolFactory.allTools(store: store)
        if let section = SkillPromptSection.build(skills: skillList) { prompt += section }
    }

    private func makeMemoryStore(config: SwiftClawConfig) -> (any MemoryProvider)? {
        if backendType == .mlx {
            let embEngine = MLXEmbeddingEngine(
                modelId: config.embeddingModelId
            ) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.embeddingState = .loading(progress)
                }
            }
            let store = try? MemoryStore(embeddingEngine: embEngine)
            if store != nil { embeddingState = .ready }
            return store
        } else {
            return try? MemoryStore()
        }
    }

    func reindexMemory() async {
        guard let store = agentMemory as? MemoryStore else { return }
        await store.reindex()
    }

    private func resolveAdapterURL() -> URL? {
        if autoAdapter {
            let store = (try? AdapterStore())
            let all = (try? store?.list()) ?? []
            if let selected = AdapterSelector().select(prompt: "", from: all, forModel: modelId),
               let url = try? store?.adapterURL(name: selected.name)
            {
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
        guard let agentSession = session else {
            // newChat must have failed (e.g., backend couldn't load). Show
            // the user's message and a useful error rather than silently
            // dropping the turn.
            messages.append(ChatBubble(kind: .user(text)))
            let why: String
            if case let .error(msg) = backendState {
                why = "Backend error: \(msg)"
            } else {
                why = "Couldn't start a session — check backend settings (Settings → General)."
            }
            messages.append(ChatBubble(kind: .warning(why)))
            isGenerating = false
            return
        }
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
            if finalText.isEmpty, response.toolCalls.isEmpty {
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
                    if let usage = response.tokenUsage { lastTokenUsage = usage }
                    // Reset streaming state for the next agentic round (tool calls may trigger more)
                    streamingBubbleId = nil
                    currentText = ""
                    currentThinking = nil

                case let .warning(msg):
                    messages.append(ChatBubble(kind: .warning(msg)))

                case let .memoryUpdated(keys):
                    messages.append(ChatBubble(kind: .warning("Memory updated: \(keys.joined(separator: ", "))")))

                case let .fileStreaming(path, partial):
                    currentlyWritingFile = (path: path, partial: partial)
                    if sessionMode == .build { canvasOpen = true }

                case let .fileWritten(path):
                    if currentlyWritingFile?.path == path {
                        currentlyWritingFile = nil
                    }
                    canvasFileWrittenPath = path

                case .done:
                    // Finalize any streaming bubble that never got a .turn (e.g. cancelled mid-stream)
                    if let id = streamingBubbleId,
                       let idx = messages.lastIndex(where: { $0.id == id })
                    {
                        if currentText.isEmpty, currentThinking == nil {
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
            // If we exited the loop via cancellation (Task.isCancelled break),
            // the .done case never fires — finalize any half-rendered
            // streaming bubble here so it doesn't render "forever streaming".
            if Task.isCancelled, let id = streamingBubbleId,
               let idx = messages.lastIndex(where: { $0.id == id })
            {
                if currentText.isEmpty, currentThinking == nil {
                    messages.remove(at: idx)
                } else {
                    messages[idx] = ChatBubble(id: id, kind: .assistant(currentText))
                }
            }
            // Auto-save after each turn (skip if cancelled)
            if !Task.isCancelled, var meta = currentMetadata {
                // Pick up live edits to mode / canvas before persisting.
                meta.mode = sessionMode
                meta.canvasSplit = canvasSplit
                meta.updatedAt = Date()
                currentMetadata = meta
                try? await agentSession.save(to: store, metadata: meta)
                await refreshSessions()
            }
        } catch {
            // Finalize any open streaming bubble before showing error
            if let id = streamingBubbleId,
               let idx = messages.lastIndex(where: { $0.id == id })
            {
                if currentText.isEmpty, currentThinking == nil {
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

    // MARK: - Model Info

    static let modelDescriptions: [String: String] = [
        "mlx-community/Qwen3.5-9B-MLX-4bit": "Created by Alibaba Cloud. 9B params, 4-bit quantized.",
        "mlx-community/Qwen2.5-7B-Instruct-4bit": "Created by Alibaba Cloud. 7B params, 4-bit quantized.",
        "mlx-community/Llama-3.2-3B-Instruct-4bit": "Meta Llama 3.2, 3B params, 4-bit quantized.",
        "mlx-community/Llama-3.3-70B-Instruct-4bit": "Meta Llama 3.3, 70B params, 4-bit quantized.",
        "mlx-community/Mistral-7B-Instruct-v0.3-4bit": "Created by Mistral AI. 7B params, 4-bit quantized.",
        "mlx-community/phi-4-4bit": "Created by Microsoft. 14B params, 4-bit quantized.",
    ]

    var modelDescription: String {
        Self.modelDescriptions[modelId] ?? "On-device language model."
    }

    private static let paramPattern: NSRegularExpression? =
        try? NSRegularExpression(pattern: "-(\\d+(?:\\.\\d+)?[bB])-?", options: [])

    var modelCapabilityBadges: [String] {
        var badges: [String] = []
        badges.append(backendType == .mlx ? "On-Device" : "HTTP")
        let lower = modelId.lowercased()
        if lower.contains("4bit") || lower.contains("4-bit") { badges.append("4-bit") }
        if lower.contains("8bit") || lower.contains("8-bit") { badges.append("8-bit") }
        // Extract param count like "9B", "70B", "3B", "7B", "14B"
        let range = NSRange(modelId.startIndex..., in: modelId)
        if let match = Self.paramPattern?.firstMatch(in: modelId, range: range),
           let r = Range(match.range(at: 1), in: modelId)
        {
            badges.append(String(modelId[r]).uppercased())
        }
        return badges
    }

    var totalRAM: String {
        let gb = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        return "\(Int(gb.rounded())) GB"
    }

    var modelCacheSize: String = "—"
    var availableStorage: String = "—"

    func refreshStorageMetrics() async {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("models")

        // Directory walk is slow — offload to background thread
        let sizeTask = Task.detached(priority: .userInitiated) { () -> Int64 in
            guard let url = cacheURL else { return 0 }
            return ChatViewModel.directorySize(at: url)
        }

        // Volume query is fast — run while background task proceeds
        if let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
            let bytes = values.volumeAvailableCapacityForImportantUsage
        {
            availableStorage = ChatViewModel.formatBytes(Int64(bytes))
        }

        let size = await sizeTask.value
        if size > 0 { modelCacheSize = ChatViewModel.formatBytes(size) }
    }

    private nonisolated static func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            total += Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }

    private nonisolated static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Bubble Rebuild

    // MARK: - Context usage

    /// Estimate of context-window usage for the active chat. Uses the
    /// backend-reported token count when available (HTTP backend), otherwise
    /// falls back to a chars/4 heuristic. `isApproximate` is true in fallback
    /// mode so the indicator can prefix the label with `~`.
    var contextUsage: (used: Int, total: Int, isApproximate: Bool) {
        let total = ModelCapabilities.forModel(id: modelId, dynamicContextWindow: discoveredContextWindow).contextWindow
        if let usage = lastTokenUsage {
            return (usage.totalTokens, total, false)
        }
        let chars = messages.reduce(0) { acc, bubble in
            acc + bubbleCharCount(bubble)
        }
        return (max(1, chars / 4), total, true)
    }

    /// Breakdown of the most recent turn's token usage, shaped for the
    /// `SCContextUsageIndicator` tooltip. Nil until a backend has reported
    /// usage (HTTP only; MLX backend doesn't emit it).
    var contextUsageBreakdown: SCContextUsageIndicator.Breakdown? {
        guard let u = lastTokenUsage else { return nil }
        return SCContextUsageIndicator.Breakdown(
            promptTokens: u.promptTokens,
            completionTokens: u.completionTokens,
            cacheReadTokens: u.cacheReadTokens,
            cacheCreationTokens: u.cacheCreationTokens
        )
    }

    private func bubbleCharCount(_ bubble: ChatBubble) -> Int {
        switch bubble.kind {
        case let .user(s), let .assistant(s): return s.count
        case let .streamingAssistant(text, thinking, _): return text.count + (thinking?.count ?? 0)
        case let .toolCall(name, _): return name.count
        case let .toolResult(content, _, _): return content.count
        case let .warning(msg): return msg.count
        case let .toolCallPending(name, arguments, _): return name.count + arguments.count
        case let .toolCallDenied(name, _): return name.count
        }
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
