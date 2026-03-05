import Foundation
import SwiftClawCore

/// Sends an email via `pippin mail send`. CAUTION: sends real email.
public struct MailSendTool: SwiftClawTool {
    public let name = "mail_send"
    public let description =
        "Send an email using pippin. CAUTION: this sends a real email immediately. Requires confirmation from the user before use."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "to":      .string(description: "Recipient email address"),
            "subject": .string(description: "Email subject"),
            "body":    .string(description: "Email body text"),
            "account": .string(description: "Sending account (optional)"),
        ],
        required: ["to", "subject", "body"]
    )

    private let runner: PippinRunner

    public init(runner: PippinRunner) {
        self.runner = runner
    }

    private struct Arguments: Decodable {
        var to: String
        var subject: String
        var body: String
        var account: String?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        var argv: [String] = ["send", "--to", args.to, "--subject", args.subject, "--body", args.body]
        if let account = args.account { argv += ["--account", account] }

        switch await runner.run(subcommand: "mail", arguments: argv) {
        case let .success(output): return .success(output)
        case let .failure(error): return .failure(error.localizedDescription)
        }
    }
}
