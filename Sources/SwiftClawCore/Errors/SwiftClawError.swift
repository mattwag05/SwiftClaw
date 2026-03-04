import Foundation

public enum SwiftClawError: LocalizedError {
    case modelLoadFailed(String)
    case generationFailed(String)
    case maxToolRoundTripsExceeded(Int)
    case toolExecutionFailed(toolName: String, detail: String)
    case invalidToolArguments(toolName: String, detail: String)
    case sessionClosed

    public var errorDescription: String? {
        switch self {
        case let .modelLoadFailed(msg):
            "Failed to load model: \(msg)"
        case let .generationFailed(msg):
            "Generation failed: \(msg)"
        case let .maxToolRoundTripsExceeded(n):
            "Exceeded maximum tool round-trips (\(n))"
        case let .toolExecutionFailed(name, detail):
            "Tool '\(name)' failed: \(detail)"
        case let .invalidToolArguments(name, detail):
            "Invalid arguments for '\(name)': \(detail)"
        case .sessionClosed:
            "Session is closed"
        }
    }
}
