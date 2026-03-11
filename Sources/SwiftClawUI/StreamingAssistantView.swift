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
        HStack(alignment: .top, spacing: 10) {
            Text("AI")
                .font(Theme.monoFont)
                .fontWeight(.bold)
                .foregroundStyle(Theme.secondaryForeground)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 6) {
                if let thinking, !thinking.isEmpty {
                    ThinkingContentView(text: thinking)
                }

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
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: Theme.bubbleMinSpacing)
        }
    }
}
