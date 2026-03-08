import ArgumentParser
import Foundation
import SwiftClawCore
import SwiftClawHTTP
import SwiftClawMLX
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

    mutating func run() async throws {
        print("SwiftClaw \(SwiftClawVersion.version)")

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
            resolvedBackend = HTTPBackend(baseURL: url, model: httpModel, apiKey: apiKey)
            print("Using HTTP backend: \(apiUrl) (model: \(httpModel))\n")
        }

        let config = (try? SwiftClawConfig.load()) ?? .default
        let tools: [any SwiftClawTool] =
            SwiftClawToolFactory.allTools(config: config) + PippinToolFactory.allTools()

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

        let sessionConfig = SessionConfiguration(maxToolRoundTrips: maxRoundTrips)
        if let sessionId = session {
            do {
                let restored = try await store.load(sessionId: sessionId)
                agentSession = Session(
                    agent: agent,
                    backend: resolvedBackend,
                    config: sessionConfig,
                    sessionId: sessionId,
                    restoredMessages: restored.messages
                )
                let count = restored.messages.filter { $0.role == .user }.count
                print("Resumed session '\(sessionId)' (\(count) prior turns).\n")
            } catch SwiftClawError.sessionNotFound {
                agentSession = Session(
                    agent: agent,
                    backend: resolvedBackend,
                    config: sessionConfig,
                    sessionId: sessionId
                )
                print("Started new session '\(sessionId)'.\n")
            }
            // Other errors (storage corruption, permissions) propagate and abort
        } else {
            agentSession = Session(
                agent: agent,
                backend: resolvedBackend,
                config: sessionConfig
            )
        }

        let metadata = SessionMetadata(agentName: agentConfig.name, modelId: model)

        print("Sysop Agent ready. Type your message (Ctrl+D to exit).\n")

        while true {
            print("> ", terminator: "")
            fflush(stdout)

            guard let line = readLine(strippingNewline: true) else {
                print("\nGoodbye.")
                break
            }

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed == "/quit" || trimmed == "/exit" {
                print("Goodbye.")
                break
            }
            if trimmed == "/help" {
                print("Commands: /help  /tools  /quit  /exit")
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
                let events = await agentSession.respond(to: trimmed)
                for try await event in events {
                    switch event {
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
                        if !response.content.isEmpty {
                            print(response.content)
                        } else if response.toolCalls.isEmpty {
                            fputs("\u{001B}[2m[empty response]\u{001B}[0m\n", stderr)
                        }
                    case .done:
                        print()
                    case let .warning(msg):
                        fputs("\u{001B}[33m[warning] \(msg)\u{001B}[0m\n", stderr)
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
