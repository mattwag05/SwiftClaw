import Foundation
import SwiftClawCore

/// Lists Voice Memos via `pippin memos list`.
public struct MemosListTool: SwiftClawTool {
    public let name = "memos_list"
    public let description =
        "List Voice Memos using pippin. Returns a JSON array of memo metadata."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "limit": .integer(description: "Maximum number of memos to return (optional)"),
        ],
        required: []
    )

    private let runner: PippinRunner

    public init(runner: PippinRunner) {
        self.runner = runner
    }

    private struct Arguments: Decodable {
        var limit: Int?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let i = try? c.decodeIfPresent(Int.self, forKey: .limit) {
                limit = i
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .limit) {
                limit = Int(s)
            } else { limit = nil }
        }

        enum CodingKeys: String, CodingKey { case limit }
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        var argv: [String] = ["list"]
        if let limit = args.limit { argv += ["--limit", String(limit)] }

        switch await runner.run(subcommand: "memos", arguments: argv) {
        case let .success(output): return .success(output)
        case let .failure(error): return .failure(error.localizedDescription)
        }
    }
}
