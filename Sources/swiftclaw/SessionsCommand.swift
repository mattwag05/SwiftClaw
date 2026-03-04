import ArgumentParser
import Foundation
import SwiftClawCore

struct SessionsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sessions",
        abstract: "Manage saved agent sessions.",
        subcommands: [ListCommand.self, ShowCommand.self, DeleteCommand.self]
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
            print(String(format: "%-36s  %-12s  %5s  %s", "SESSION ID", "AGENT", "MSGS", "LAST UPDATED"))
            print(String(repeating: "-", count: 80))
            for s in summaries {
                let date = formatter.string(from: s.updatedAt)
                let preview = s.preview.isEmpty ? "(no messages)" : s.preview
                print(String(format: "%-36s  %-12s  %5d  %s", s.sessionId, s.agentName, s.messageCount, date))
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
