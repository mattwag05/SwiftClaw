import SwiftUI

/// Compact search field with leading magnifying-glass icon and trailing clear button.
///
/// Use for filter bars and list headers. The clear button is only shown when
/// `text` is non-empty and tapping it sets `text` back to the empty string.
public struct SCSearchInput: View {
    private let placeholder: String
    @Binding private var text: String

    @FocusState private var isFocused: Bool

    public init(text: Binding<String>, placeholder: String = "Search") {
        _text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.foregroundTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .textStyle(.body)
                .foregroundStyle(Theme.foregroundPrimary)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.foregroundTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 32)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

#Preview("SCSearchInput — light") {
    @Previewable @State var empty = ""
    @Previewable @State var filled = "mlx"

    return VStack(alignment: .leading, spacing: Spacing.md) {
        SCSearchInput(text: $empty)
        SCSearchInput(text: $filled, placeholder: "Filter sessions")
    }
    .padding(Spacing.xl)
    .frame(width: 320)
    .background(Theme.background)
    .preferredColorScheme(.light)
}

#Preview("SCSearchInput — dark") {
    @Previewable @State var text = "cortex"

    return VStack(alignment: .leading, spacing: Spacing.md) {
        SCSearchInput(text: $text, placeholder: "Search…")
    }
    .padding(Spacing.xl)
    .frame(width: 320)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
