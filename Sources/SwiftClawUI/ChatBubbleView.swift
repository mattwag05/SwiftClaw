import SwiftUI

public struct ChatBubbleView: View {
    public let bubble: ChatBubble
    public var onApproveToolCall: ((String) -> Void)?
    public var onDenyToolCall: ((String) -> Void)?

    public init(
        bubble: ChatBubble,
        onApproveToolCall: ((String) -> Void)? = nil,
        onDenyToolCall: ((String) -> Void)? = nil
    ) {
        self.bubble = bubble
        self.onApproveToolCall = onApproveToolCall
        self.onDenyToolCall = onDenyToolCall
    }

    public var body: some View {
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
}
