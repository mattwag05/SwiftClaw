import SwiftUI

public struct AssistantMessageView: View {
    public let text: String

    public init(text: String) { self.text = text }

    public var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "cpu.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.secondaryForeground)
                .padding(.top, 2)
            MarkdownTextView(text: text)
                .padding(Theme.bubblePadding)
                .background(Theme.assistantBubbleBackground, in: RoundedRectangle(cornerRadius: Theme.bubbleCornerRadius))
            Spacer(minLength: Theme.bubbleMinSpacing)
        }
    }
}
