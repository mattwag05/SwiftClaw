import ArgumentParser
import Foundation
import SwiftClawCore
import SwiftClawMLX
import SwiftClawTools

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Start an interactive Sysop Agent session."
    )

    @Option(name: .long, help: "Model ID (Hugging Face).")
    var model: String = "mlx-community/Qwen3.5-9B-MLX-4bit"

    @Option(name: .long, help: "Maximum tokens per response.")
    var maxTokens: Int = 4096

    @Option(name: .long, help: "Maximum tool round-trips per turn.")
    var maxRoundTrips: Int = 10

    mutating func run() async throws {
        print("SwiftClaw \(SwiftClawVersion.version)")
        print("Loading model: \(model)...")

        let backend = try await loadMLXBackend(modelId: model) { progress in
            let pct = Int(progress * 100)
            if pct % 10 == 0 {
                print("  Download: \(pct)%", terminator: "\r")
                fflush(stdout)
            }
        }
        print("Model loaded.\n")

        let tools: [any SwiftClawTool] = [
            SystemInfoTool(),
            DiskSpaceTool(),
            ProcessListTool(),
            ShellTool(),
        ]

        let agent = Agent(configuration: AgentConfiguration(
            name: "SysopAgent",
            systemPrompt: """
                You are Sysop, a macOS system administration assistant. You have access to tools \
                for checking system information, disk space, running processes, and executing \
                sandboxed shell commands. Use these tools to help the user with system administration \
                tasks. Be concise and accurate. When you use a tool, explain what you found.
                """,
            tools: tools,
            modelId: model,
            generationConfig: GenerationConfig(maxTokens: maxTokens)
        ))

        let session = Session(
            agent: agent,
            backend: backend,
            config: SessionConfiguration(maxToolRoundTrips: maxRoundTrips)
        )

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

            do {
                let events = await session.respond(to: trimmed)
                for try await event in events {
                    switch event {
                    case let .textDelta(text):
                        print(text, terminator: "")
                        fflush(stdout)
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
                        }
                    case .done:
                        print()
                    }
                }
            } catch {
                print("\nError: \(error.localizedDescription)")
            }
        }
    }
}
