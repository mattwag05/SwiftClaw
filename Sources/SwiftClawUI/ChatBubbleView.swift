import SwiftUI

public struct ChatBubbleView: View {
    public let bubble: ChatBubble

    public init(bubble: ChatBubble) { self.bubble = bubble }

    public var body: some View {
        switch bubble.kind {
        case let .user(text):
            UserMessageView(text: text)
        case let .assistant(text):
            AssistantMessageView(text: text)
        case let .toolCall(name, _):
            ToolCallBubbleView(name: name)
        case let .toolResult(content, isError, _):
            ToolResultBubbleView(content: content, isError: isError)
        case let .warning(msg):
            WarningBubbleView(message: msg)
        }
    }
}
