import Foundation
import SwiftClawCore

/// Read recent stdout/stderr output from a monitored process's ring buffer.
public struct ProcessOutputTool: SwiftClawTool {
    public let name = "process_output"
    public let description =
        "Read recent stdout/stderr output from a monitored process's ring buffer."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "process_id": .string(description: "The process ID returned by start_process."),
            "tail": .integer(description: "Number of recent lines to return (default: 50)."),
        ],
        required: ["process_id"]
    )

    private let monitor: ProcessMonitor

    public init(monitor: ProcessMonitor) {
        self.monitor = monitor
    }

    private struct Arguments: Decodable {
        let processId: String
        let tail: Int?

        enum CodingKeys: String, CodingKey {
            case processId = "process_id"
            case tail
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            processId = try c.decode(String.self, forKey: .processId)
            if let i = try? c.decodeIfPresent(Int.self, forKey: .tail) {
                tail = i
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .tail) {
                tail = Int(s)
            } else {
                tail = nil
            }
        }
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        if let lines = await monitor.output(id: args.processId, tail: args.tail ?? 50) {
            if lines.isEmpty {
                return .success("(no output yet)")
            }
            return .success(lines.joined(separator: "\n"))
        } else {
            return .failure("Process \(args.processId) not found")
        }
    }
}
