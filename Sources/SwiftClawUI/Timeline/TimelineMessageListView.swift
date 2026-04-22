import SwiftUI

/// Alternative chat renderer: flat, edge-to-edge timeline with a left connector
/// rail. Mirrors `ChatBubbleView`'s public approve/deny API so callers can swap
/// between the bubble and timeline presentations with no other changes.
public struct TimelineMessageListView: View {
    public let messages: [ChatBubble]
    public var onApproveToolCall: ((String) -> Void)?
    public var onDenyToolCall: ((String) -> Void)?

    public init(
        messages: [ChatBubble],
        onApproveToolCall: ((String) -> Void)? = nil,
        onDenyToolCall: ((String) -> Void)? = nil
    ) {
        self.messages = messages
        self.onApproveToolCall = onApproveToolCall
        self.onDenyToolCall = onDenyToolCall
    }

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: Spacing.lg) {
            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                TimelineRow(
                    bubble: message,
                    isLast: index == messages.count - 1,
                    onApproveToolCall: onApproveToolCall,
                    onDenyToolCall: onDenyToolCall
                )
            }
        }
    }
}

// MARK: - Row

private struct TimelineRow: View {
    let bubble: ChatBubble
    let isLast: Bool
    let onApproveToolCall: ((String) -> Void)?
    let onDenyToolCall: ((String) -> Void)?

    private static let railWidth: CGFloat = 24
    private static let dotSize: CGFloat = 8

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            rail
                .frame(width: Self.railWidth)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let label = senderLabel {
                    Text(label)
                        .textStyle(.captionEmph)
                        .foregroundStyle(dotColor)
                }
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Rail

    private var rail: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                if !isLast {
                    Rectangle()
                        .fill(Theme.borderSubtle)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .offset(x: (Self.railWidth / 2) - 0.5, y: Self.dotSize)
                }
                Circle()
                    .fill(dotColor)
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .offset(
                        x: (Self.railWidth / 2) - (Self.dotSize / 2),
                        y: 4
                    )
                Color.clear.frame(height: geo.size.height)
            }
        }
    }

    // MARK: - Message content

    @ViewBuilder
    private var content: some View {
        switch bubble.kind {
        case let .user(text):
            MarkdownContentView(text: text)
        case let .assistant(text):
            MarkdownContentView(text: text)
        case let .streamingAssistant(text, _, _):
            MarkdownContentView(text: text)
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

    // MARK: - Style

    private var dotColor: Color {
        switch bubble.kind {
        case .user:
            return Theme.accentSecondary
        case .assistant, .streamingAssistant:
            return Theme.accent
        case .toolCall, .toolResult, .toolCallPending, .toolCallDenied:
            return Theme.foregroundSecondary
        case .warning:
            return Theme.warning
        }
    }

    private var senderLabel: String? {
        switch bubble.kind {
        case .user:
            return "YOU"
        case .assistant, .streamingAssistant:
            return "SYSOP"
        default:
            return nil
        }
    }
}

// MARK: - Preview

#Preview("Timeline — mixed transcript") {
    TimelineMessageListView(
        messages: [
            ChatBubble(kind: .user("What files changed in the last commit?")),
            ChatBubble(kind: .streamingAssistant(
                text: "Let me check the git log for you.",
                thinking: nil,
                isStreaming: false
            )),
            ChatBubble(kind: .toolCall(name: "bash:git log", callId: "c1")),
            ChatBubble(kind: .toolResult(
                content: "7de7623 docs: add superpowers specs directory\na4244ff fix: remove .atomic from WriteFileTool",
                isError: false,
                callId: "c1"
            )),
            ChatBubble(kind: .assistant(
                "Two commits: a docs addition for the superpowers specs directory, and a fix removing `.atomic` from `WriteFileTool`."
            )),
            ChatBubble(kind: .warning("Rate limit approaching — 50 requests remaining.")),
        ]
    )
    .padding(Spacing.xl)
    .frame(width: 560)
    .background(Theme.background)
}
