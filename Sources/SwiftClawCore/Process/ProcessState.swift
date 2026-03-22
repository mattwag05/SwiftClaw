import Foundation

/// State of a process managed by ``ProcessMonitor``.
public enum ProcessState: Sendable, Equatable {
    case launching
    case ready
    case failed(String)
    case stopped(Int32)  // exit code
}

extension ProcessState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .launching:           return "launching"
        case .ready:               return "ready"
        case .failed(let msg):     return "failed: \(msg)"
        case .stopped(let code):   return "stopped (exit \(code))"
        }
    }
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
