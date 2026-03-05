import Foundation
import SwiftClawCore

/// Shows metadata for a Voice Memo via `pippin memos info`.
public struct MemosInfoTool: SwiftClawTool {
    public let name = "memos_info"
    public let description =
        "Get metadata for a specific Voice Memo using pippin. Returns JSON with duration, date, and file info."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "id": .string(description: "Memo ID or identifier"),
        ],
        required: ["id"]
    )

    private let runner: PippinRunner

    public init(runner: PippinRunner) {
        self.runner = runner
    }

    private struct Arguments: Decodable {
        var id: String
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        switch await runner.run(subcommand: "memos", arguments: ["info", args.id]) {
        case let .success(output): return .success(output)
        case let .failure(error): return .failure(error.localizedDescription)
        }
    }
}
