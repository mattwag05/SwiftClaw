import SwiftUI

public struct UserMessageView: View {
    public let text: String

    public init(text: String) { self.text = text }

    public var body: some View {
        HStack {
            Spacer(minLength: Theme.bubbleMinSpacing)
            Text(text)
                .textSelection(.enabled)
                .padding(Theme.bubblePadding)
                .background(Theme.userBubbleBackground, in: RoundedRectangle(cornerRadius: Theme.bubbleCornerRadius))
                .foregroundStyle(Theme.userBubbleForeground)
        }
    }
}
