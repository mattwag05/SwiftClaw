import ArgumentParser
import Foundation
import SwiftClawCore
import SwiftClawHTTP
import SwiftClawMLX
import SwiftClawMemory
import SwiftClawPippin
import SwiftClawTools

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Start an interactive Sysop Agent session."
    )

    enum BackendChoice: String, ExpressibleByArgument {
        case mlx, http
    }

    @Option(name: .long, help: "Backend: mlx (on-device) or http (OpenAI-compatible API).")
    var backend: BackendChoice = .mlx

    @Option(name: .long, help: "Model ID (Hugging Face for MLX, or model name for HTTP).")
    var model: String = SwiftClawVersion.defaultModelId

    @Option(name: .long, help: "Base URL for HTTP backend (e.g. http://localhost:11434/v1).")
    var apiUrl: String = "http://localhost:11434/v1"

    @Option(name: .long, help: "API key for HTTP backend (optional).")
    var apiKey: String?

    @Option(name: .long, help: "Maximum tokens per response.")
    var maxTokens: Int = 4096

    @Option(name: .long, help: "Maximum tool round-trips per turn.")
    var maxRoundTrips: Int = 10

    @Option(name: .long, help: "Session ID to create or resume.")
    var session: String?

    @Option(name: .long, help: "Path to a trained LoRA adapter directory (MLX backend only).")
    var adapter: String?

    @Flag(name: .long, help: "Auto-select the best adapter for this session (MLX only, ignored when --adapter is set).")
    var autoAdapter: Bool = false

    @Flag(name: .long, help: "Enable memory consolidation — persist facts across turns.")
    var memory: Bool = false

    @Option(name: [.customLong("cache-mode")], help: "Prompt caching mode: none, anthropic, openai (HTTP backend only).")
    var cacheModeStr: String?

    mutating func run() async throws {
        print("SwiftClaw \(SwiftClawVersion.version)")

        let config = (try? SwiftClawConfig.load()) ?? .default
        let resolvedBackend: any ModelBackend
        switch backend {
        case .mlx:
            var adapterURL = adapter.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            if adapterURL == nil && autoAdapter {
                // No prompt context at startup — tag component scores 0; selection falls back to loss+recency.
                let context = ""
                let adapterStore = try AdapterStore()
                let allAdapters = (try? adapterStore.list()) ?? []
                let selected = AdapterSelector().select(prompt: context, from: allAdapters, forModel: model)
                if let selected, let url = try? adapterStore.adapterURL(name: selected.name) {
                    let tagSuffix = selected.tags.isEmpty ? "" : " [tags: \(selected.tags.joined(separator: ", "))]"
                    print("Auto-selected adapter: \(selected.name)\(tagSuffix)")
                    adapterURL = url
                } else {
                    print("Auto-adapter: no suitable adapter found, using base model.")
                }
            }
            if let adapterURL { print("Loading adapter: \(adapterURL.path)") }
            print("Loading model: \(model)...")
            resolvedBackend = try await loadMLXBackend(modelId: model, adapterPath: adapterURL) { progress in
                let pct = Int(progress * 100)
                if pct % 10 == 0 {
                    print("  Download: \(pct)%", terminator: "\r")
                    fflush(stdout)
                }
            }
            print("Model loaded.\n")
        case .http:
            guard let url = URL(string: apiUrl) else {
                throw ValidationError("Invalid API URL: \(apiUrl)")
            }
            let httpModel = model == SwiftClawVersion.defaultModelId ? "qwen2.5:7b" : model
            let cacheMode = cacheModeStr.flatMap(CacheMode.init(rawValue:)) ?? config.cacheMode
            resolvedBackend = HTTPBackend(baseURL: url, model: httpModel, apiKey: apiKey, cacheMode: cacheMode)
            print("Using HTTP backend: \(apiUrl) (model: \(httpModel))\n")
        }

        let agentMemory: (any MemoryProvider)?
        if memory {
            do {
                if backend == .mlx {
                    let embeddingEngine = MLXEmbeddingEngine(modelId: config.embeddingModelId) { progress in
                        let pct = Int(progress * 100)
                        if pct % 10 == 0 {
                            fputs("[embedding] download: \(pct)%\n", stderr)
                        }
                    }
                    agentMemory = try MemoryStore(embeddingEngine: embeddingEngine)
                } else {
                    agentMemory = try MemoryStore()
                }
            } catch {
                fputs("[memory] failed to initialize store: \(error.localizedDescription)\n", stderr)
                throw error
            }
        } else {
            agentMemory = nil
        }
        let processMonitor = ProcessMonitor()
        var tools: [any SwiftClawTool] =
            SwiftClawToolFactory.allTools(config: config)
            + PippinToolFactory.allTools()
            + SwiftClawToolFactory.processTools(monitor: processMonitor)
        if let memStore = agentMemory {
            tools += MemoryToolFactory.allTools(store: memStore)
        }

        let agentConfig = AgentConfiguration(
            name: "SysopAgent",
            systemPrompt: """
                You are Sysop, a macOS assistant. You have access to tools for system administration, \
                file operations (read, write, list, find — sandboxed to allowed paths), \
                environment inspection (env vars, date/time, clipboard), \
                and pippin CLI wrappers for Apple Mail and Voice Memos (when pippin is installed). \
                Be concise and accurate. When you use a tool, explain what you found. \
                For mail_send, always confirm with the user before sending.
                """,
            tools: tools,
            modelId: model,
            generationConfig: GenerationConfig(maxTokens: maxTokens)
        )
        let agent = Agent(configuration: agentConfig)

        // Resolve session ID and optionally restore from saved state
        let store = try FileSessionStore()
        let agentSession: Session

        var sessionConfig = SessionConfiguration(maxToolRoundTrips: maxRoundTrips)
        sessionConfig.memoryEnabled = memory
        sessionConfig.consolidationInterval = config.consolidationInterval
        if let threshold = config.compressionTokenThreshold {
            sessionConfig.compressionTokenThreshold = threshold
        }
        sessionConfig.retrievalTopK = config.retrievalTopK
        sessionConfig.retrievalThreshold = config.retrievalThreshold

        if memory { print("Memory enabled\n") }
        if let sessionId = session {
            do {
                let restored = try await store.load(sessionId: sessionId)
                agentSession = Session(
                    agent: agent,
                    backend: resolvedBackend,
                    config: sessionConfig,
                    sessionId: sessionId,
                    restoredMessages: restored.messages,
                    memory: agentMemory,
                    processMonitor: processMonitor
                )
                let count = restored.messages.filter { $0.role == .user }.count
                print("Resumed session '\(sessionId)' (\(count) prior turns).\n")
            } catch SwiftClawError.sessionNotFound {
                agentSession = Session(
                    agent: agent,
                    backend: resolvedBackend,
                    config: sessionConfig,
                    sessionId: sessionId,
                    memory: agentMemory,
                    processMonitor: processMonitor
                )
                print("Started new session '\(sessionId)'.\n")
            }
            // Other errors (storage corruption, permissions) propagate and abort
        } else {
            agentSession = Session(
                agent: agent,
                backend: resolvedBackend,
                config: sessionConfig,
                memory: agentMemory,
                processMonitor: processMonitor
            )
        }

        let metadata = SessionMetadata(agentName: agentConfig.name, modelId: model)

        print("Sysop Agent ready. Type your message (Ctrl+D to exit).\n")

        while true {
            print("> ", terminator: "")
            fflush(stdout)

            guard let line = readLine(strippingNewline: true) else {
                print("\nGoodbye.")
                await agentSession.endSession()
                break
            }

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed == "/quit" || trimmed == "/exit" {
                print("Goodbye.")
                await agentSession.endSession()
                break
            }
            if trimmed == "/help" {
                let memCmd = memory ? "  /memory  " : ""
                print("Commands: /help  /tools\(memCmd)  /processes  /quit  /exit")
                continue
            }
            if trimmed == "/memory" || trimmed.hasPrefix("/memory ") {
                guard let mem = agentMemory else {
                    print("Memory not enabled. Run with --memory to enable.")
                    continue
                }
                if trimmed.hasPrefix("/memory search ") {
                    let query = String(trimmed.dropFirst("/memory search ".count))
                    let results = (try? await mem.search(query: query, layer: nil, topK: 10)) ?? []
                    if results.isEmpty {
                        print("No memories found.")
                    } else {
                        for r in results {
                            print("[\(String(format: "%.2f", r.score))] \(r.entry.key): \(r.entry.content)")
                        }
                    }
                } else if trimmed == "/memory clear working" {
                    try? await mem.clearLayer(.working)
                    print("Working memory cleared.")
                } else if trimmed == "/memory clear all" {
                    print("This will clear ALL memories including long-term. Type 'yes' to confirm:")
                    if let confirm = readLine(), confirm.lowercased() == "yes" {
                        try? await mem.clearLayer(.working)
                        try? await mem.clearLayer(.longTerm)
                        print("All memory cleared.")
                    } else {
                        print("Cancelled.")
                    }
                } else {
                    // Show all memories
                    let all = await mem.allEntries(layer: nil)
                    if all.isEmpty {
                        print("(no memories stored)")
                    } else {
                        for entry in all.sorted(by: { $0.key < $1.key }) {
                            print("- \(entry.key): \(entry.content)")
                        }
                    }
                }
                continue
            }
            if trimmed == "/processes" || trimmed.hasPrefix("/processes ") {
                if trimmed == "/processes" {
                    let procs = await processMonitor.list()
                    if procs.isEmpty {
                        print("No monitored processes.")
                    } else {
                        for p in procs {
                            let pid = p.pid.map { " [pid \($0)]" } ?? ""
                            print("  \(p.id.prefix(8)): \(p.state)\(pid)  \(p.command)")
                        }
                    }
                } else if trimmed.hasPrefix("/processes stop ") {
                    let id = String(trimmed.dropFirst("/processes stop ".count)).trimmingCharacters(in: .whitespaces)
                    do {
                        try await processMonitor.stop(id: id)
                        print("Process stopped.")
                    } catch {
                        print("Error: \(error.localizedDescription)")
                    }
                } else if trimmed.hasPrefix("/processes show ") {
                    let id = String(trimmed.dropFirst("/processes show ".count)).trimmingCharacters(in: .whitespaces)
                    if let lines = await processMonitor.output(id: id) {
                        print(lines.joined(separator: "\n"))
                    } else {
                        print("Process not found: \(id)")
                    }
                } else {
                    print("Unknown /processes subcommand. Usage: /processes  /processes stop <id>  /processes show <id>")
                }
                continue
            }
            if trimmed == "/tools" {
                print("Registered tools:")
                for name in agent.toolRegistry.toolNames {
                    print("  \(name)")
                }
                continue
            }
            if trimmed.hasPrefix("/") {
                print("Unknown command. Type /help for available commands.")
                continue
            }

            do {
                var receivedTextDelta = false
                let events = await agentSession.respond(to: trimmed)
                for try await event in events {
                    switch event {
                    case let .textDelta(text):
                        receivedTextDelta = true
                        print(text, terminator: "")
                        fflush(stdout)
                    case let .thinkingDelta(text):
                        // Show thinking content in dim text
                        fputs("\u{001B}[2m\(text)\u{001B}[0m", stdout)
                        fflush(stdout)
                    case let .toolCallPending(_, name, _):
                        // CLI has no delegate — this case won't occur in practice
                        print("\n[pending \(name)]", terminator: "")
                    case let .toolCallDenied(_, name):
                        print("\n[denied \(name)]", terminator: "")
                    case let .toolCallStart(_, name):
                        print("\n[calling \(name)...]", terminator: "")
                        fflush(stdout)
                    case let .toolResult(_, result):
                        if result.isError {
                            print(" error: \(result.content)")
                        } else {
                            print(" done.")
                        }
                    case let .turn(response):
                        if receivedTextDelta {
                            // Text was already printed via .textDelta — nothing more to print
                            receivedTextDelta = false
                        } else if !response.content.isEmpty {
                            // Non-streaming backend fallback: print full content
                            print(response.content)
                        } else if response.toolCalls.isEmpty {
                            fputs("\u{001B}[2m[empty response]\u{001B}[0m\n", stderr)
                        }
                        if let usage = response.tokenUsage, usage.cacheReadTokens != nil || usage.cacheCreationTokens != nil {
                            let read = usage.cacheReadTokens ?? 0
                            let creation = usage.cacheCreationTokens ?? 0
                            fputs("\u{001B}[2m[cache: \(read) read, \(creation) created]\u{001B}[0m\n", stderr)
                        }
                    case .done:
                        print()
                    case let .warning(msg):
                        fputs("\u{001B}[33m[warning] \(msg)\u{001B}[0m\n", stderr)
                    case let .memoryUpdated(keys):
                        fputs("\u{001B}[2m[memory] stored: \(keys.joined(separator: ", "))\u{001B}[0m\n", stderr)
                    }
                }
                // Auto-save after each complete turn
                try await agentSession.save(to: store, metadata: metadata)
            } catch {
                print("\nError: \(error.localizedDescription)")
            }
        }
    }
}
