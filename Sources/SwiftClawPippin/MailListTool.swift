import Foundation
import SwiftClawCore

/// Lists mail messages via `pippin mail list`.
public struct MailListTool: SwiftClawTool {
    public let name = "mail_list"
    public let description =
        "List mail messages using pippin. Returns a JSON array of recent messages."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "account":  .string(description: "Mail account to list (optional)"),
            "mailbox":  .string(description: "Mailbox/folder name (optional, default: INBOX)"),
            "limit":    .integer(description: "Maximum number of messages (optional)"),
            "unread":   .boolean(description: "Only show unread messages (optional)"),
        ],
        required: []
    )

    private let runner: PippinRunner

    public init(runner: PippinRunner) {
        self.runner = runner
    }

    private struct Arguments: Decodable {
        var account: String?
        var mailbox: String?
        var limit: Int?
        var unread: Bool?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            account = try? c.decodeIfPresent(String.self, forKey: .account)
            mailbox = try? c.decodeIfPresent(String.self, forKey: .mailbox)
            if let i = try? c.decodeIfPresent(Int.self, forKey: .limit) {
                limit = i
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .limit) {
                limit = Int(s)
            } else { limit = nil }
            if let b = try? c.decodeIfPresent(Bool.self, forKey: .unread) {
                unread = b
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .unread) {
                unread = s.lowercased() == "true"
            } else { unread = nil }
        }

        enum CodingKeys: String, CodingKey { case account, mailbox, limit, unread }
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        var argv: [String] = ["list"]
        if let account = args.account { argv += ["--account", account] }
        if let mailbox = args.mailbox { argv += ["--mailbox", mailbox] }
        if let limit = args.limit { argv += ["--limit", String(limit)] }
        if args.unread == true { argv.append("--unread") }

        switch await runner.run(subcommand: "mail", arguments: argv) {
        case let .success(output): return .success(output)
        case let .failure(error): return .failure(error.localizedDescription)
        }
    }
}
