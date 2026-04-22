import SwiftUI

/// Chrome wrapper for popover content. Pass this view as the content of a
/// `.popover(isPresented:)` modifier — `SCPopover` does NOT present itself.
///
/// Useful for quick-settings panels, status cards, or command-palette-embedded
/// views. Width may be pinned (default 280pt) or left `nil` to let the content
/// size itself.
public struct SCPopover<Content: View>: View {
    private let width: CGFloat?
    private let content: Content

    public init(width: CGFloat? = 280, @ViewBuilder content: () -> Content) {
        self.width = width
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Spacing.md)
            .frame(width: width, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Theme.surfaceRaised)
            )
            .shadow(color: Theme.shadow, radius: 16, x: 0, y: 4)
    }
}

#Preview("SCPopover — light") {
    SCPopover {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Quick settings")
                .textStyle(.subheading)
                .foregroundStyle(Theme.foregroundPrimary)
            Text("Toggle streaming, adjust temperature, or pick a different model.")
                .textStyle(.caption)
                .foregroundStyle(Theme.foregroundSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    .padding(Spacing.xl)
    .background(Theme.background)
}

#Preview("SCPopover — dark, auto-width") {
    SCPopover(width: nil) {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(Theme.accent)
            Text("Ready")
                .textStyle(.bodyEmph)
                .foregroundStyle(Theme.foregroundPrimary)
        }
    }
    .padding(Spacing.xl)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
