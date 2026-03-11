import SwiftUI

public struct AssistantMessageView: View {
    public let text: String

    public init(text: String) { self.text = text }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Small monospace "AI" tag as avatar
            Text("AI")
                .font(Theme.monoFont)
                .fontWeight(.bold)
                .foregroundStyle(Theme.secondaryForeground)
                .padding(.top, 3)

            MarkdownContentView(text: text)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: Theme.bubbleMinSpacing)
        }
    }
}
