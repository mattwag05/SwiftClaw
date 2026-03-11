import Foundation
import SwiftClawCore

/// Moves mail messages to a different mailbox via `pippin mail move`.
public struct MailMoveTool: SwiftClawTool {
    public let name = "mail_move"
    public let requiresConfirmation = true
    public let description =
        "Move one or more mail messages to a different mailbox using pippin."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "ids":        .string(description: "Comma-separated message IDs to move"),
            "to_mailbox": .string(description: "Destination mailbox/folder name"),
            "account":    .string(description: "Mail account (optional)"),
        ],
        required: ["ids", "to_mailbox"]
    )

    private let runner: PippinRunner

    public init(runner: PippinRunner) {
        self.runner = runner
    }

    private struct Arguments: Decodable {
        var ids: String
        var toMailbox: String
        var account: String?

        enum CodingKeys: String, CodingKey {
            case ids, toMailbox = "to_mailbox", account
        }
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        var argv: [String] = ["move", "--ids", args.ids, "--to", args.toMailbox]
        if let account = args.account { argv += ["--account", account] }

        switch await runner.run(subcommand: "mail", arguments: argv) {
        case let .success(output): return .success(output)
        case let .failure(error): return .failure(error.localizedDescription)
        }
    }
}
