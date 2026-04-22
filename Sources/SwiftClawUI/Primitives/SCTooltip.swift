import SwiftUI

public extension View {
    /// Shows `text` on pointer hover. Currently bridges to SwiftUI's `.help()`
    /// so macOS draws a native system tooltip. The wrapper exists so callers
    /// use a consistent name; later PRs may customize rendering.
    func tooltip(_ text: String) -> some View {
        help(text)
    }
}

#Preview("SCTooltip") {
    VStack(spacing: Spacing.md) {
        Text("Hover the button to see the tooltip")
            .textStyle(.caption)
            .foregroundStyle(Theme.foregroundSecondary)

        Button {
            // no-op
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Theme.accent)
                )
        }
        .buttonStyle(.plain)
        .tooltip("Generate a suggestion")
    }
    .padding(Spacing.xl)
    .background(Theme.background)
}
