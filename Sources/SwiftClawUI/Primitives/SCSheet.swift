import SwiftUI

/// Chrome wrapper for sheet content. Pass this view as the content of a
/// `.sheet(isPresented:)` modifier — `SCSheet` does NOT present itself.
///
/// Provides a consistent raised surface with an optional title header, an
/// optional dismiss button, and a hairline divider separating header from
/// content.
public struct SCSheet<Content: View>: View {
    private let title: String?
    private let onDismiss: (() -> Void)?
    private let content: Content

    public init(
        title: String? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.onDismiss = onDismiss
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                HStack(alignment: .center, spacing: Spacing.sm) {
                    Text(title)
                        .textStyle(.heading)
                        .foregroundStyle(Theme.foregroundPrimary)
                    Spacer(minLength: Spacing.sm)
                    if let onDismiss {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.foregroundSecondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                                .accessibilityHidden(true)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityLabel("Dismiss")
                        .help("Dismiss")
                    }
                }
                Rectangle()
                    .fill(Theme.borderSubtle)
                    .frame(height: 1)
                    .padding(.top, Spacing.md)
            }

            content
                .padding(.top, title == nil ? 0 : Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Theme.surfaceRaised)
        )
    }
}

#Preview("SCSheet — light") {
    SCSheet(title: "Edit Session", onDismiss: {}) {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Rename this session or change its model.")
                .textStyle(.body)
                .foregroundStyle(Theme.foregroundSecondary)
            Text("Session title")
                .textStyle(.caption)
                .foregroundStyle(Theme.foregroundTertiary)
        }
    }
    .frame(width: 420)
    .padding(Spacing.xl)
    .background(Theme.background)
}

#Preview("SCSheet — dark, no dismiss") {
    SCSheet(title: "Confirmation") {
        Text("Are you sure you want to continue?")
            .textStyle(.body)
            .foregroundStyle(Theme.foregroundPrimary)
    }
    .frame(width: 420)
    .padding(Spacing.xl)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
