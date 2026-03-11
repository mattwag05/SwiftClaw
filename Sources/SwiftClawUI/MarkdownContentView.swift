import SwiftUI

// MARK: - MarkdownSegment

enum MarkdownSegment {
    case text(String)
    case codeBlock(language: String?, code: String)

    static func parse(_ text: String) -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []
        let pattern = "```(\\w*)\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(text)]
        }
        var lastEnd = text.startIndex
        let nsText = text as NSString
        regex.enumerateMatches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ) { match, _, _ in
            guard let match else { return }
            guard let matchRange = Range(match.range, in: text) else { return }
            // Text before code block
            if lastEnd < matchRange.lowerBound {
                let before = String(text[lastEnd..<matchRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !before.isEmpty { segments.append(.text(before)) }
            }
            let lang = Range(match.range(at: 1), in: text).map { String(text[$0]) }
            let code = Range(match.range(at: 2), in: text).map { String(text[$0]) } ?? ""
            segments.append(.codeBlock(
                language: lang?.isEmpty == true ? nil : lang,
                code: code.trimmingCharacters(in: .newlines)
            ))
            lastEnd = matchRange.upperBound
        }
        // Remaining text after last code block
        if lastEnd < text.endIndex {
            let remaining = String(text[lastEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty { segments.append(.text(remaining)) }
        }
        return segments.isEmpty ? [.text(text)] : segments
    }
}

// MARK: - MarkdownContentView

/// Renders text with inline markdown and styled fenced code blocks with copy buttons.
public struct MarkdownContentView: View {
    public let text: String

    public init(text: String) { self.text = text }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(MarkdownSegment.parse(text).enumerated()), id: \.offset) { _, segment in
                switch segment {
                case let .text(content):
                    Text(attributedString(from: content))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case let .codeBlock(language, code):
                    CodeBlockView(language: language, code: code)
                }
            }
        }
    }

    private func attributedString(from text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(text)
    }
}
