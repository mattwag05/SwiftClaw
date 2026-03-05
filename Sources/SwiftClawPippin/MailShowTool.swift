import Foundation
import SwiftClawCore

/// Shows a single mail message via `pippin mail show`.
public struct MailShowTool: SwiftClawTool {
    public let name = "mail_show"
    public let description =
        "Show the full content of a mail message using pippin. Returns JSON with headers and body."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "id":      .string(description: "Message ID or identifier"),
            "account": .string(description: "Mail account (optional)"),
        ],
        required: ["id"]
    )

    private let runner: PippinRunner

    public init(runner: PippinRunner) {
        self.runner = runner
    }

    private struct Arguments: Decodable {
        var id: String
        var account: String?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        var argv: [String] = ["show", args.id]
        if let account = args.account { argv += ["--account", account] }

        switch await runner.run(subcommand: "mail", arguments: argv) {
        case let .success(output): return .success(output)
        case let .failure(error): return .failure(error.localizedDescription)
        }
    }
}
