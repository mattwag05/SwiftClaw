import Foundation

public enum SwiftClawError: LocalizedError, Equatable {
    case modelLoadFailed(String)
    case generationFailed(String)
    case maxToolRoundTripsExceeded(Int)
    case toolExecutionFailed(toolName: String, detail: String)
    case sessionClosed
    case httpRequestFailed(statusCode: Int, body: String)
    case sseParsingFailed(String)
    case sessionNotFound(String)
    case storageError(String)
    case trainingFailed(String)
    case adapterNotFound(String)
    case insufficientTrainingData(String)
    case consolidationFailed(String)
    case compressionFailed(String)
    case embeddingModelNotFound(String)
    case embeddingFailed(String)
    case memoryDatabaseError(String)

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
        case .sessionClosed:
            "Session is closed"
        case let .httpRequestFailed(code, body):
            "HTTP request failed (\(code)): \(body)"
        case let .sseParsingFailed(detail):
            "SSE parsing failed: \(detail)"
        case let .sessionNotFound(id):
            "Session not found: \(id)"
        case let .storageError(detail):
            "Storage error: \(detail)"
        case let .trainingFailed(detail):
            "Training failed: \(detail)"
        case let .adapterNotFound(name):
            "Adapter not found: \(name)"
        case let .insufficientTrainingData(detail):
            "Insufficient training data: \(detail)"
        case let .consolidationFailed(detail):
            "Memory consolidation failed: \(detail)"
        case let .compressionFailed(detail):
            "Context compression failed: \(detail)"
        case let .embeddingModelNotFound(id):
            "Embedding model not found: \(id)"
        case let .embeddingFailed(detail):
            "Embedding failed: \(detail)"
        case let .memoryDatabaseError(detail):
            "Memory database error: \(detail)"
        }
    }
}
