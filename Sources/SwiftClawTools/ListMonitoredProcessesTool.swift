import Foundation
import SwiftClawCore

/// List all background processes currently monitored in this session.
public struct ListMonitoredProcessesTool: SwiftClawTool {
    public let name = "list_monitored_processes"
    public let description =
        "List all background processes currently monitored in this session."

    public let parameterSchema: JSONSchema = .object(properties: [:], required: [])

    private let monitor: ProcessMonitor

    public init(monitor: ProcessMonitor) {
        self.monitor = monitor
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let procs = await monitor.list()
        if procs.isEmpty {
            return .success("No monitored processes.")
        }
        let lines = procs.map { p -> String in
            let stateStr: String
            switch p.state {
            case .launching: stateStr = "launching"
            case .ready: stateStr = "ready"
            case .failed(let msg): stateStr = "failed: \(msg)"
            case .stopped(let code): stateStr = "stopped (exit \(code))"
            }
            let pidStr = p.pid.map { " [pid \($0)]" } ?? ""
            let argsStr = p.args.isEmpty ? "" : " " + p.args.joined(separator: " ")
            return "ID: \(p.id)  state: \(stateStr)\(pidStr)  \(p.command)\(argsStr)"
        }
        return .success(lines.joined(separator: "\n"))
    }
}
