import SwiftUI

/// Rounded card with a titled header, optional subtitle, and divider above its
/// body content.
///
/// Use when a card needs a label + supporting copy above arbitrary content.
public struct SCSectionCard<Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let content: Content

    public init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .textStyle(.subheading)
                    .foregroundStyle(Theme.foregroundPrimary)
                if let subtitle {
                    Text(subtitle)
                        .textStyle(.caption)
                        .foregroundStyle(Theme.foregroundSecondary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            Rectangle()
                .fill(Theme.borderSubtle)
                .frame(height: 1)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }
}

#Preview("Default") {
    VStack(spacing: Spacing.lg) {
        SCSectionCard("Session") {
            Text("Main card body content goes here.")
                .textStyle(.body)
                .foregroundStyle(Theme.foregroundPrimary)
        }

        SCSectionCard("Diagnostics", subtitle: "Last updated 2 minutes ago") {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Model: qwen3.5")
                    .textStyle(.body)
                    .foregroundStyle(Theme.foregroundPrimary)
                Text("Context: 8,192 tokens")
                    .textStyle(.caption)
                    .foregroundStyle(Theme.foregroundSecondary)
            }
        }
    }
    .padding(Spacing.xl)
    .frame(width: 420)
    .background(Theme.background)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: Spacing.lg) {
        SCSectionCard("Session") {
            Text("Main card body content goes here.")
                .textStyle(.body)
                .foregroundStyle(Theme.foregroundPrimary)
        }

        SCSectionCard("Diagnostics", subtitle: "Last updated 2 minutes ago") {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Model: qwen3.5")
                    .textStyle(.body)
                    .foregroundStyle(Theme.foregroundPrimary)
                Text("Context: 8,192 tokens")
                    .textStyle(.caption)
                    .foregroundStyle(Theme.foregroundSecondary)
            }
        }
    }
    .padding(Spacing.xl)
    .frame(width: 420)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
