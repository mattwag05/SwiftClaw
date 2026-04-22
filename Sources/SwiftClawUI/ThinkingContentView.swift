import SwiftUI

/// Thin alias preserved for existing call sites.
///
/// The real implementation lives in `ReasoningDisplayView`, which splits a
/// single raw reasoning blob into independently expandable groups and items.
/// New code should prefer `ReasoningDisplayView` directly.
public struct ThinkingContentView: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        ReasoningDisplayView(rawText: text)
    }
}

#Preview {
    ThinkingContentView(
        text: """
        Double-checking the alias still compiles.
        Delegates straight through to ReasoningDisplayView.

        No additional behaviour lives here anymore.
        """
    )
    .padding(Spacing.lg)
    .frame(width: 420)
    .background(Theme.surface)
    .preferredColorScheme(.light)
}
