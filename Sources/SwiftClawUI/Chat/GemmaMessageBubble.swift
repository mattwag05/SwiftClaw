import SwiftUI

/// A single chat bubble, styled per `ChatBubble.Kind`.
public struct GemmaMessageBubble: View {
    public let bubble: ChatBubble
    public var onApprove: ((String) -> Void)?
    public var onDeny: ((String) -> Void)?
    public var onCopy: ((ChatBubble) -> Void)?
    public var onRegenerate: ((ChatBubble) -> Void)?

    @State private var thinkingExpanded = false

    public init(
        bubble: ChatBubble,
        onApprove: ((String) -> Void)? = nil,
        onDeny: ((String) -> Void)? = nil,
        onCopy: ((ChatBubble) -> Void)? = nil,
        onRegenerate: ((ChatBubble) -> Void)? = nil
    ) {
        self.bubble = bubble
        self.onApprove = onApprove
        self.onDeny = onDeny
        self.onCopy = onCopy
        self.onRegenerate = onRegenerate
    }

    public var body: some View {
        switch bubble.kind {
        case let .user(text):
            userBubble(text: text)

        case let .assistant(text):
            assistantBubble(text: text, isStreaming: false, thinking: nil)

        case let .streamingAssistant(text, thinking, isStreaming):
            assistantBubble(text: text, isStreaming: isStreaming, thinking: thinking)

        case .toolCall, .toolCallPending, .toolCallDenied, .toolResult:
            GemmaToolCallCard(kind: bubble.kind, onApprove: onApprove, onDeny: onDeny)
                .padding(.leading, 44)

        case let .warning(msg):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#fbbf24"))
                Text(msg)
                    .font(.system(size: 12.5))
                    .foregroundStyle(GemmaForeground.primary)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: "#fbbf24").opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(hex: "#fbbf24").opacity(0.25), lineWidth: 1)
            )
            .padding(.leading, 44)
        }
    }

    // MARK: - User bubble

    private func userBubble(text: String) -> some View {
        HStack {
            Spacer(minLength: 60)
            Text(text)
                .font(.body)
                .foregroundStyle(GemmaForeground.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Surface.s08)
                .clipShape(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(
                            topLeading: GemmaRadius.bubble,
                            bottomLeading: GemmaRadius.bubble,
                            bottomTrailing: GemmaRadius.bubbleTR,
                            topTrailing: GemmaRadius.bubble
                        )
                    )
                )
                .frame(maxWidth: UIConstants.maxUserBubbleWidth, alignment: .trailing)
                .contextMenu { copyButton }
        }
    }

    // MARK: - Assistant bubble

    private func assistantBubble(text: String, isStreaming: Bool, thinking: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            avatarView
            VStack(alignment: .leading, spacing: 6) {
                if let thinking, !thinking.isEmpty {
                    thinkingSection(thinking)
                }
                if !text.isEmpty || isStreaming {
                    if text.isEmpty, isStreaming, (thinking ?? "").isEmpty {
                        // Pre-first-token state — show pulsing dots so the user
                        // knows the model is actually working.
                        ThinkingDotsView()
                            .padding(.vertical, 2)
                    } else {
                        HStack(alignment: .bottom, spacing: 2) {
                            Text(text)
                                .font(.body)
                                .foregroundStyle(GemmaForeground.primary)
                                .textSelection(.enabled)
                            if isStreaming {
                                StreamingCaret()
                                    .foregroundStyle(GemmaForeground.secondary)
                            }
                        }
                    }
                }
                if isStreaming && !text.isEmpty {
                    GemmaActivityBar(charCount: text.count)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contextMenu {
                copyButton
                regenerateButton
            }
        }
    }

    // MARK: - Avatar

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Surface.s08)
                .frame(width: 28, height: 28)
            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundStyle(GemmaForeground.secondary)
        }
    }

    // MARK: - Thinking section

    private func thinkingSection(_ thinking: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.gemmaQuick) { thinkingExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "brain")
                        .font(.caption2)
                        .foregroundStyle(GemmaForeground.tertiary)
                    Text("Thinking")
                        .font(.caption2)
                        .foregroundStyle(GemmaForeground.tertiary)
                    Image(systemName: thinkingExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(GemmaForeground.tertiary)
                }
            }
            .buttonStyle(.plain)

            if thinkingExpanded {
                Text(thinking)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(GemmaForeground.tertiary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Surface.s04)
                    .clipShape(RoundedRectangle(cornerRadius: GemmaRadius.sm))
            }
        }
    }

    // MARK: - Context menu items

    private var copyButton: some View {
        Button("Copy") { onCopy?(bubble) }
    }

    private var regenerateButton: some View {
        Button("Regenerate") { onRegenerate?(bubble) }
    }
}

// MARK: - Layout constants

private enum UIConstants {
    static let maxUserBubbleWidth: CGFloat = GemmaLayout.messageMaxWidth * 0.78
}
