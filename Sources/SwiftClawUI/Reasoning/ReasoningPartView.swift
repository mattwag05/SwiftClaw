import SwiftUI

/// Leaf text block for a reasoning item's expanded body.
///
/// Pure content — no chrome, no header, no background. Renders selectable,
/// wrapping monospaced text so long reasoning paragraphs read cleanly and
/// remain copy-friendly.
struct ReasoningPartView: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(.codeInline)
            .foregroundStyle(Theme.foregroundSecondary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Short") {
    ReasoningPartView(text: "Checked whether the user wanted a summary first.")
        .padding(Spacing.lg)
        .frame(width: 360)
        .background(Theme.surface)
        .preferredColorScheme(.light)
}

#Preview("Long") {
    ReasoningPartView(
        text: """
        The request is ambiguous between two interpretations. One reading \
        treats it as a literal substring match, the other as a structural \
        parse. I'll go with the structural parse because the surrounding \
        plan mentions "groups" and "items" explicitly.
        """
    )
    .padding(Spacing.lg)
    .frame(width: 360)
    .background(Theme.surface)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ReasoningPartView(text: "Verifying the hypothesis against the failing test.")
        .padding(Spacing.lg)
        .frame(width: 360)
        .background(Theme.surface)
        .preferredColorScheme(.dark)
}
