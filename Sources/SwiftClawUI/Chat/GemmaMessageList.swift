import SwiftUI

/// Scrollable list of chat bubbles with staggered entry animation.
/// Replaces `ChatTranscriptView` in Phase 6 sessions.
public struct GemmaMessageList: View {
    public let messages: [ChatBubble]
    public var onApproveToolCall: ((String) -> Void)?
    public var onDenyToolCall: ((String) -> Void)?
    public var onCopyBubble: ((ChatBubble) -> Void)?
    public var onRegenerateBubble: ((ChatBubble) -> Void)?

    public init(
        messages: [ChatBubble],
        onApproveToolCall: ((String) -> Void)? = nil,
        onDenyToolCall: ((String) -> Void)? = nil,
        onCopyBubble: ((ChatBubble) -> Void)? = nil,
        onRegenerateBubble: ((ChatBubble) -> Void)? = nil
    ) {
        self.messages = messages
        self.onApproveToolCall = onApproveToolCall
        self.onDenyToolCall = onDenyToolCall
        self.onCopyBubble = onCopyBubble
        self.onRegenerateBubble = onRegenerateBubble
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, bubble in
                        GemmaMessageBubble(
                            bubble: bubble,
                            onApprove: onApproveToolCall,
                            onDeny: onDenyToolCall,
                            onCopy: onCopyBubble,
                            onRegenerate: onRegenerateBubble
                        )
                        .transition(.gemmaMessageEntry)
                        .animation(
                            .gemmaSnap.delay(GemmaStagger.delay(for: index)),
                            value: messages.count
                        )
                        .id(bubble.id)
                        .frame(maxWidth: GemmaLayout.messageMaxWidth, alignment: .leading)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.gemmaQuick) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: messages.last?.kind.textPreview) { _, _ in
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}
