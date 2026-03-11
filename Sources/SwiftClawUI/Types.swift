import Foundation

// MARK: - Chat Bubble

/// View-layer representation of a single chat message.
public struct ChatBubble: Identifiable, Sendable {
    public let id: UUID
    public let kind: Kind

    public init(id: UUID = UUID(), kind: Kind) {
        self.id = id
        self.kind = kind
    }

    public enum Kind: Sendable {
        case user(String)
        case assistant(String)
        /// Assistant message being streamed — text accumulates, cursor shows while isStreaming.
        case streamingAssistant(text: String, thinking: String?, isStreaming: Bool)
        case toolCall(name: String, callId: String)
        case toolResult(content: String, isError: Bool, callId: String)
        case warning(String)
        case toolCallPending(name: String, arguments: String, callId: String)
        case toolCallDenied(name: String, callId: String)

        /// Trailing text suffix used for scroll-position change detection.
        public var textPreview: String? {
            switch self {
            case let .streamingAssistant(text, _, _): return text.isEmpty ? nil : String(text.suffix(20))
            case let .assistant(text): return String(text.suffix(20))
            default: return nil
            }
        }
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
