import Foundation
import SwiftClawCore

/// Stop a monitored background process (SIGTERM then SIGKILL).
public struct StopProcessTool: SwiftClawTool {
    public let name = "stop_process"
    public let requiresConfirmation = true
    public let description =
        "Stop a monitored background process (SIGTERM then SIGKILL)."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "process_id": .string(description: "The process ID returned by start_process."),
        ],
        required: ["process_id"]
    )

    private let monitor: ProcessMonitor

    public init(monitor: ProcessMonitor) {
        self.monitor = monitor
    }

    private struct Arguments: Decodable {
        let processId: String

        enum CodingKeys: String, CodingKey {
            case processId = "process_id"
        }
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        do {
            try await monitor.stop(id: args.processId)
            return .success("Process \(args.processId) stopped.")
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
