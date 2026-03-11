import SwiftUI

/// Assistant message view for both in-progress streaming and finalized messages with thinking content.
public struct StreamingAssistantView: View {
    public let text: String
    public let thinking: String?
    public let isStreaming: Bool

    @State private var cursorOn = false

    public init(text: String, thinking: String?, isStreaming: Bool) {
        self.text = text
        self.thinking = thinking
        self.isStreaming = isStreaming
    }

    public var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "cpu.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.secondaryForeground)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                if let thinking, !thinking.isEmpty {
                    ThinkingContentView(text: thinking)
                }

                VStack(alignment: .leading, spacing: 0) {
                    if text.isEmpty && isStreaming {
                        ThinkingDotsView()
                    } else {
                        HStack(alignment: .bottom, spacing: 0) {
                            MarkdownContentView(text: text)
                            if isStreaming {
                                Text("▌")
                                    .foregroundStyle(Theme.primaryForeground)
                                    .opacity(cursorOn ? 1 : 0)
                                    .animation(
                                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                                        value: cursorOn
                                    )
                                    .onAppear { cursorOn = true }
                            }
                        }
                    }
                }
                .padding(Theme.bubblePadding)
                .background(
                    Theme.assistantBubbleBackground,
                    in: RoundedRectangle(cornerRadius: Theme.bubbleCornerRadius)
                )
            }

            Spacer(minLength: Theme.bubbleMinSpacing)
        }
    }
}
