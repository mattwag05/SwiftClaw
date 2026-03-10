import SwiftUI

public struct MarkdownTextView: View {
    public let text: String

    public init(text: String) { self.text = text }

    public var body: some View {
        Text(attributedString)
            .textSelection(.enabled)
    }

    private var attributedString: AttributedString {
        (try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(text)
    }
}
