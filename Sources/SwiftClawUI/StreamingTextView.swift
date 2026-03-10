import SwiftUI

/// Shows a pulsing "Thinking…" indicator while the model reasons,
/// then displays streaming text once the thinking phase ends.
public struct StreamingTextView: View {
    public let text: String
    public let isThinking: Bool

    public init(text: String, isThinking: Bool) {
        self.text = text
        self.isThinking = isThinking
    }

    public var body: some View {
        if isThinking {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                    .symbolEffect(.pulse)
                    .foregroundStyle(.secondary)
                Text("Thinking…")
                    .foregroundStyle(.secondary)
                    .italic()
            }
            .padding(Theme.bubblePadding)
        } else if !text.isEmpty {
            MarkdownTextView(text: text)
                .padding(Theme.bubblePadding)
                .background(Theme.assistantBubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.bubbleCornerRadius))
                .textSelection(.enabled)
        }
    }
}
