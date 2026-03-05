import Foundation
import SwiftClawCore

/// Transcribes a Voice Memo via `pippin memos transcribe`.
public struct MemosTranscribeTool: SwiftClawTool {
    public let name = "memos_transcribe"
    public let description =
        "Transcribe a Voice Memo using pippin. Returns the transcription text as JSON."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "id": .string(description: "Memo ID or identifier to transcribe"),
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

        // Transcription can take time — use a longer timeout
        switch await runner.run(subcommand: "memos", arguments: ["transcribe", args.id], timeout: 120) {
        case let .success(output): return .success(output)
        case let .failure(error): return .failure(error.localizedDescription)
        }
    }
}
