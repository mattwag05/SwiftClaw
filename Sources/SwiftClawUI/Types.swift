import Foundation

// MARK: - Chat Bubble

/// View-layer representation of a single chat message.
public struct ChatBubble: Identifiable, Sendable {
    public let id = UUID()
    public let kind: Kind

    public init(kind: Kind) { self.kind = kind }

    public enum Kind: Sendable {
        case user(String)
        case assistant(String)
        case toolCall(name: String, callId: String)
        case toolResult(content: String, isError: Bool, callId: String)
        case warning(String)
    }
}

// MARK: - Backend Display

public enum BackendType: String, CaseIterable, Sendable {
    case mlx = "MLX (On-Device)"
    case http = "HTTP (Ollama / OpenAI)"
}

public enum BackendState: Equatable, Sendable {
    case idle
    case loading(Double)   // 0.0 – 1.0
    case ready
    case error(String)
}
