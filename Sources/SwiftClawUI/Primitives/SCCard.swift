import SwiftUI

/// Generic rounded card surface.
///
/// Neutral chrome wrapper for any content. Use `SCSectionCard` when you need a
/// titled header, or `SCStatusCard` for status-row variants.
public struct SCCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    public init(padding: CGFloat = Spacing.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
        // Optional subtle elevation — uncomment when the design calls for it.
        // .shadow(color: Theme.shadow, radius: 8, x: 0, y: 2)
    }
}

#Preview("Default") {
    VStack(spacing: Spacing.lg) {
        SCCard {
            Text("A simple card with default padding.")
                .textStyle(.body)
                .foregroundStyle(Theme.foregroundPrimary)
        }

        SCCard(padding: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Tighter card")
                    .textStyle(.bodyEmph)
                    .foregroundStyle(Theme.foregroundPrimary)
                Text("Uses Spacing.md inner padding.")
                    .textStyle(.caption)
                    .foregroundStyle(Theme.foregroundSecondary)
            }
        }
    }
    .padding(Spacing.xl)
    .frame(width: 360)
    .background(Theme.background)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: Spacing.lg) {
        SCCard {
            Text("A simple card with default padding.")
                .textStyle(.body)
                .foregroundStyle(Theme.foregroundPrimary)
        }

        SCCard(padding: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Tighter card")
                    .textStyle(.bodyEmph)
                    .foregroundStyle(Theme.foregroundPrimary)
                Text("Uses Spacing.md inner padding.")
                    .textStyle(.caption)
                    .foregroundStyle(Theme.foregroundSecondary)
            }
        }
    }
    .padding(Spacing.xl)
    .frame(width: 360)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
