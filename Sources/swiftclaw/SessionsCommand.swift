import ArgumentParser
import Foundation
import SwiftClawCore

struct SessionsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sessions",
        abstract: "Manage saved agent sessions.",
        subcommands: [ListCommand.self, ShowCommand.self, DeleteCommand.self, ExportCommand.self]
    )

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all saved sessions."
        )

        mutating func run() async throws {
            let store = try FileSessionStore()
            let summaries = try await store.list()
            if summaries.isEmpty {
                print("No saved sessions.")
                return
            }
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            func col(_ s: String, _ w: Int) -> String { s.padding(toLength: w, withPad: " ", startingAt: 0) }
            print("\(col("SESSION ID", 36))  \(col("AGENT", 12))  \(col("MSGS", 5))  LAST UPDATED")
            print(String(repeating: "-", count: 80))
            for s in summaries {
                let date = formatter.string(from: s.updatedAt)
                let preview = s.preview.isEmpty ? "(no messages)" : s.preview
                let countStr = String(s.messageCount).padding(toLength: 5, withPad: " ", startingAt: 0)
                print("\(col(s.sessionId, 36))  \(col(s.agentName, 12))  \(countStr)  \(date)")
                print("  \(preview)")
            }
        }
    }

    struct ShowCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Print the conversation history for a session."
        )

        @Argument(help: "Session ID to display.")
        var sessionId: String

        mutating func run() async throws {
            let store = try FileSessionStore()
            let (messages, metadata) = try await store.load(sessionId: sessionId)
            print("Session: \(sessionId)")
            print("Agent:   \(metadata.agentName)  |  Model: \(metadata.modelId)")
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            print("Created: \(formatter.string(from: metadata.createdAt))  Updated: \(formatter.string(from: metadata.updatedAt))")
            print(String(repeating: "─", count: 60))
            for msg in messages where msg.role != .system {
                let role = msg.role.rawValue.uppercased()
                if let calls = msg.toolCalls, !calls.isEmpty {
                    print("[\(role)] <tool calls: \(calls.map(\.name).joined(separator: ", "))>")
                } else {
                    print("[\(role)] \(msg.content)")
                }
            }
        }
    }

    struct ExportCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "export",
            abstract: "Export sessions as JSONL for LoRA fine-tuning."
        )

        @Argument(help: "Session ID to export (omit with --all).")
        var sessionId: String?

        @Flag(help: "Export all saved sessions.")
        var all: Bool = false

        @Option(name: .long, help: "Output file path (default: stdout).")
        var output: String?

        @Option(name: .long, help: "Skip sessions with fewer than N messages.")
        var minMessages: Int?

        mutating func run() async throws {
            let store = try FileSessionStore()
            var batches: [[Message]] = []

            if all {
                let summaries = try await store.list()
                let threshold = minMessages ?? 0
                for summary in summaries {
                    guard summary.messageCount >= threshold else { continue }
                    do {
                        let (messages, _) = try await store.load(sessionId: summary.sessionId)
                        batches.append(messages)
                    } catch {
                        fputs("Warning: skipping session '\(summary.sessionId)': \(error.localizedDescription)\n", stderr)
                    }
                }
                fputs("Exporting \(batches.count) session(s).\n", stderr)
            } else {
                guard let id = sessionId else {
                    fputs("Error: provide a session ID or use --all.\n", stderr)
                    throw ExitCode.failure
                }
                let (messages, _) = try await store.load(sessionId: id)
                batches.append(messages)
            }

            let data = try TraceExporter.exportAll(batches)

            if let path = output {
                let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                try data.write(to: url, options: .atomic)
                fputs("Wrote \(data.count) bytes to \(path).\n", stderr)
            } else {
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data("\n".utf8))
            }
        }
    }

    struct DeleteCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Delete a saved session."
        )

        @Argument(help: "Session ID to delete.")
        var sessionId: String

        mutating func run() async throws {
            let store = try FileSessionStore()
            try await store.delete(sessionId: sessionId)
            print("Deleted session '\(sessionId)'.")
        }
    }
}
