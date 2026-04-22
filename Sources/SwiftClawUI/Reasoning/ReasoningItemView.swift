import SwiftUI

/// One reasoning step — a single paragraph in the model's thinking stream.
///
/// Collapsed: a rail dot plus a one-line preview clipped to the first line.
/// Expanded: the full text wrapped by `ReasoningPartView`. Click toggles.
struct ReasoningItemView: View {
    let text: String

    @State private var isExpanded: Bool = false

    /// First non-empty line, used as the collapsed preview.
    private var preview: String {
        text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? text
    }

    /// True when the body differs from the preview — controls whether we
    /// surface a chevron hint.
    private var hasMore: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) != preview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            header
            if isExpanded {
                ReasoningPartView(text: text)
                    .padding(.leading, Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) {
                isExpanded.toggle()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Circle()
                .fill(Theme.accent.opacity(0.6))
                .frame(width: Spacing.xs + Spacing.xxs, height: Spacing.xs + Spacing.xxs)
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }

            Text(preview)
                .textStyle(.body)
                .foregroundStyle(Theme.foregroundPrimary)
                .lineLimit(isExpanded ? nil : 1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hasMore {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.foregroundTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview("Collapsed") {
    ReasoningItemView(
        text: "Reviewed the file and found the current DisclosureGroup renders everything in one monospaced block."
    )
    .padding(Spacing.lg)
    .frame(width: 360)
    .background(Theme.surface)
    .preferredColorScheme(.light)
}

#Preview("Multi-line") {
    ReasoningItemView(
        text: """
        The split rule needs to be conservative so we don't fragment a \
        single coherent thought into multiple items. Double newlines are \
        the group boundary; single newlines are items.
        """
    )
    .padding(Spacing.lg)
    .frame(width: 360)
    .background(Theme.surface)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ReasoningItemView(text: "Quick sanity check on the preview truncation.")
        .padding(Spacing.lg)
        .frame(width: 360)
        .background(Theme.surface)
        .preferredColorScheme(.dark)
}
