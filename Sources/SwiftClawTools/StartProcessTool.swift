import Foundation
import SwiftClawCore

/// Launch a long-running background process and optionally wait for a ready marker on stdout.
public struct StartProcessTool: SwiftClawTool {
    public let name = "start_process"
    public let requiresConfirmation = true
    public let description =
        "Launch a long-running background process and optionally wait for a ready marker on its stdout. Returns a process ID for subsequent output/stop operations."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "command": .string(description: "Command to execute. Use full path (e.g. '/usr/bin/python3 server.py') or a name resolved via env PATH."),
            "args": .array(items: .string(description: nil), description: "Arguments to pass to the command (optional)."),
            "ready_marker": .string(description: "Text to watch for in stdout indicating the process is ready. If omitted, returns immediately after launch."),
            "timeout": .integer(description: "Seconds to wait for the ready marker (default 30)."),
        ],
        required: ["command"]
    )

    private let monitor: ProcessMonitor

    public init(monitor: ProcessMonitor) {
        self.monitor = monitor
    }

    private struct Arguments: Decodable {
        let command: String
        let args: [String]?
        let readyMarker: String?
        let timeout: Int?

        enum CodingKeys: String, CodingKey {
            case command, args
            case readyMarker = "ready_marker"
            case timeout
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            command = try c.decode(String.self, forKey: .command)
            args = try? c.decodeIfPresent([String].self, forKey: .args)
            readyMarker = try? c.decodeIfPresent(String.self, forKey: .readyMarker)
            if let i = try? c.decodeIfPresent(Int.self, forKey: .timeout) {
                timeout = i
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .timeout) {
                timeout = Int(s)
            } else {
                timeout = nil
            }
        }
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        let id = try await monitor.launch(
            command: args.command,
            args: args.args ?? [],
            readyMarker: args.readyMarker,
            timeout: TimeInterval(args.timeout ?? 30)
        )
        let procs = await monitor.list()
        let state = procs.first(where: { $0.id == id })?.state
        let stateStr: String
        switch state {
        case .ready: stateStr = "ready"
        case .launching: stateStr = "launching"
        case .failed(let msg): stateStr = "failed: \(msg)"
        case .stopped(let code): stateStr = "stopped (exit \(code))"
        case nil: stateStr = "unknown"
        }
        return .success("Launched process '\(args.command)' with ID: \(id)\nState: \(stateStr)")
    }
}
