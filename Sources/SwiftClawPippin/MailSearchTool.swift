import Foundation
import SwiftClawCore

/// Searches mail messages via `pippin mail search`.
public struct MailSearchTool: SwiftClawTool {
    public let name = "mail_search"
    public let description =
        "Search mail messages using pippin. Returns a JSON array of matching messages."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "query":   .string(description: "Search query string"),
            "account": .string(description: "Mail account to search (optional)"),
            "limit":   .integer(description: "Maximum number of results (optional)"),
        ],
        required: ["query"]
    )

    private let runner: PippinRunner

    public init(runner: PippinRunner) {
        self.runner = runner
    }

    private struct Arguments: Decodable {
        var query: String
        var account: String?
        var limit: Int?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            query = try c.decode(String.self, forKey: .query)
            account = try? c.decodeIfPresent(String.self, forKey: .account)
            if let i = try? c.decodeIfPresent(Int.self, forKey: .limit) {
                limit = i
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .limit) {
                limit = Int(s)
            } else { limit = nil }
        }

        enum CodingKeys: String, CodingKey { case query, account, limit }
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        var argv: [String] = ["search", args.query]
        if let account = args.account { argv += ["--account", account] }
        if let limit = args.limit { argv += ["--limit", String(limit)] }

        switch await runner.run(subcommand: "mail", arguments: argv) {
        case let .success(output): return .success(output)
        case let .failure(error): return .failure(error.localizedDescription)
        }
    }
}
