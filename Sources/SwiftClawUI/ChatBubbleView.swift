import SwiftUI

public struct ChatBubbleView: View {
    public let bubble: ChatBubble
    public var onApproveToolCall: ((String) -> Void)?
    public var onDenyToolCall: ((String) -> Void)?
    public var onCopy: (() -> Void)?
    public var onRegenerate: (() -> Void)?

    public init(
        bubble: ChatBubble,
        onApproveToolCall: ((String) -> Void)? = nil,
        onDenyToolCall: ((String) -> Void)? = nil,
        onCopy: (() -> Void)? = nil,
        onRegenerate: (() -> Void)? = nil
    ) {
        self.bubble = bubble
        self.onApproveToolCall = onApproveToolCall
        self.onDenyToolCall = onDenyToolCall
        self.onCopy = onCopy
        self.onRegenerate = onRegenerate
    }

    public var body: some View {
        content
            .contextMenu { menuItems }
    }

    @ViewBuilder private var content: some View {
        switch bubble.kind {
        case let .user(text):
            UserMessageView(text: text)
        case let .assistant(text):
            AssistantMessageView(text: text)
        case let .streamingAssistant(text, thinking, isStreaming):
            StreamingAssistantView(text: text, thinking: thinking, isStreaming: isStreaming)
        case let .toolCall(name, _):
            ToolCallBubbleView(name: name)
        case let .toolResult(content, isError, _):
            ToolResultBubbleView(content: content, isError: isError)
        case let .warning(msg):
            WarningBubbleView(message: msg)
        case let .toolCallPending(name, arguments, callId):
            ToolCallPendingView(
                name: name,
                arguments: arguments,
                onApprove: { onApproveToolCall?(callId) },
                onDeny: { onDenyToolCall?(callId) }
            )
        case let .toolCallDenied(name, _):
            ToolCallDeniedView(name: name)
        }
    }

    @ViewBuilder private var menuItems: some View {
        if canCopy, let onCopy {
            Button {
                onCopy()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        if canRegenerate, let onRegenerate {
            Button {
                onRegenerate()
            } label: {
                Label("Regenerate Response", systemImage: "arrow.clockwise")
            }
        }
    }

    private var canCopy: Bool {
        switch bubble.kind {
        case .user, .assistant, .streamingAssistant, .toolResult, .warning:
            return true
        default:
            return false
        }
    }

    private var canRegenerate: Bool {
        switch bubble.kind {
        case .assistant, .streamingAssistant:
            return true
        default:
            return false
        }
    }
}
