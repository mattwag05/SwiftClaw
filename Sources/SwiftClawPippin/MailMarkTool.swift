import Foundation
import SwiftClawCore

/// Marks mail messages as read/unread via `pippin mail mark`.
public struct MailMarkTool: SwiftClawTool {
    public let name = "mail_mark"
    public let requiresConfirmation = true
    public let description =
        "Mark one or more mail messages as read or unread using pippin."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "ids":     .string(description: "Comma-separated message IDs to mark"),
            "status":  .enumeration(values: ["read", "unread"],
                                    description: "Target read status"),
            "account": .string(description: "Mail account (optional)"),
        ],
        required: ["ids", "status"]
    )

    private let runner: PippinRunner

    public init(runner: PippinRunner) {
        self.runner = runner
    }

    private struct Arguments: Decodable {
        var ids: String
        var status: String
        var account: String?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        var argv: [String] = ["mark", "--ids", args.ids, "--status", args.status]
        if let account = args.account { argv += ["--account", account] }

        switch await runner.run(subcommand: "mail", arguments: argv) {
        case let .success(output): return .success(output)
        case let .failure(error): return .failure(error.localizedDescription)
        }
    }
}
