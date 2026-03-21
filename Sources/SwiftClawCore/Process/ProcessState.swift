import Foundation

/// State of a process managed by ``ProcessMonitor``.
public enum ProcessState: Sendable {
    case launching
    case ready
    case failed(String)
    case stopped(Int32)  // exit code
}

/// Snapshot of a monitored process.
public struct MonitoredProcess: Sendable {
    public let id: String
    public let command: String
    public let args: [String]
    public var state: ProcessState
    public let pid: Int32?
    public let startTime: Date
}
