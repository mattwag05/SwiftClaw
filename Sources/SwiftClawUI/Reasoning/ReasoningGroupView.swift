import SwiftUI

/// One contiguous "thinking burst" — a vertical stack of reasoning items
/// that were separated only by single newlines in the source stream.
///
/// Structural parity with the original raw text is the goal, so there is no
/// summary/title row: items are rendered in order with a stable gap.
struct ReasoningGroupView: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                ReasoningItemView(text: item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Single item") {
    ReasoningGroupView(items: [
        "Considered whether the user meant a literal match or a structural parse.",
    ])
    .padding(Spacing.lg)
    .frame(width: 360)
    .background(Theme.surface)
    .preferredColorScheme(.light)
}

#Preview("Several items") {
    ReasoningGroupView(items: [
        "First, confirm the file currently bundles reasoning into one block.",
        "Second, plan the four-view split under Reasoning/.",
        "Third, keep ThinkingContentView as a thin alias.",
    ])
    .padding(Spacing.lg)
    .frame(width: 360)
    .background(Theme.surface)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ReasoningGroupView(items: [
        "The rail dot should be subtle enough to recede.",
        "But still visible against the cream surface.",
    ])
    .padding(Spacing.lg)
    .frame(width: 360)
    .background(Theme.surface)
    .preferredColorScheme(.dark)
}
