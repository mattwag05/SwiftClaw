import SwiftUI

/// Top-level wrapper for an entire assistant turn's reasoning stream.
///
/// Parses the raw thinking text into contiguous groups (double-newline
/// boundaries) of items (single-newline boundaries), then renders each group
/// as a `ReasoningGroupView` stacked along a shared left rail. The whole
/// block is wrapped in a DisclosureGroup so the viewer can collapse every
/// reasoning step at once; individual items also expand independently.
public struct ReasoningDisplayView: View {
    public let rawText: String

    @State private var isExpanded: Bool = false

    public init(rawText: String) {
        self.rawText = rawText
    }

    /// Grouped items parsed out of `rawText`.
    ///
    /// - Trim leading/trailing whitespace on the whole blob.
    /// - Split on runs of two-or-more newlines for groups; 3+ newline runs
    ///   produce interior empty groups that drop out via the empty-filter.
    /// - Split each group on single newlines for items.
    /// - Drop empty strings at either level.
    private var groups: [[String]] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return trimmed
            .components(separatedBy: "\n\n")
            .map { group in
                group
                    .split(separator: "\n", omittingEmptySubsequences: true)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
            .filter { !$0.isEmpty }
    }

    public var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
                .padding(.top, Spacing.sm)
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "brain")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.foregroundSecondary)
                    .accessibilityHidden(true)
                Text("Reasoning")
                    .textStyle(.captionEmph)
                    .foregroundStyle(Theme.foregroundSecondary)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
        .padding(.leading, Spacing.xs)
    }

    @ViewBuilder
    private var content: some View {
        let parsed = groups
        if parsed.isEmpty {
            EmptyView()
        } else {
            HStack(alignment: .top, spacing: Spacing.md) {
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(Array(parsed.enumerated()), id: \.offset) { _, items in
                        ReasoningGroupView(items: items)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, Spacing.xs)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Single group") {
    ReasoningDisplayView(
        rawText: """
        Looking at the request.
        It wants a four-view split with structural parity.
        """
    )
    .padding(Spacing.lg)
    .frame(width: 420)
    .background(Theme.surface)
    .preferredColorScheme(.light)
}

#Preview("Multi-group") {
    ReasoningDisplayView(
        rawText: """
        First pass: inspect the current ThinkingContentView.
        Confirms a single DisclosureGroup renders the whole blob.

        Second pass: design the split.
        Groups on double newlines, items on single newlines.
        Drop empty strings at both levels.

        Third pass: verify the build stays green.
        """
    )
    .padding(Spacing.lg)
    .frame(width: 420)
    .background(Theme.surface)
    .preferredColorScheme(.light)
}

#Preview("Long paragraphs (dark)") {
    ReasoningDisplayView(
        rawText: """
        The user's raw text may contain long paragraphs that wrap across many \
        visible lines without ever introducing a newline character. That's \
        fine — each paragraph collapses to a single-line preview until the \
        user expands it, at which point the wrapping text surfaces in full.

        A second burst starts here. It includes multiple steps:
        Parse the blob.
        Trim whitespace.
        Split on boundaries.
        Render each group along the shared rail.
        """
    )
    .padding(Spacing.lg)
    .frame(width: 420)
    .background(Theme.surface)
    .preferredColorScheme(.dark)
}
