import SwiftUI

/// Multi-line text field that grows between a min and max height.
///
/// Built on `TextField(axis: .vertical)`; line limits are derived from the
/// pixel bounds using a ~20pt line-height approximation. Return submits (calls
/// `onSubmit`); Shift+Return inserts a newline (native TextField behavior).
public struct SCAutosizeTextarea: View {
    private let placeholder: String
    private let minHeight: CGFloat
    private let maxHeight: CGFloat
    private let onSubmit: () -> Void
    @Binding private var text: String

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "",
        minHeight: CGFloat = 36,
        maxHeight: CGFloat = 140,
        onSubmit: @escaping () -> Void
    ) {
        _text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.onSubmit = onSubmit
    }

    public var body: some View {
        let approxLineHeight: CGFloat = 20
        let minLines = max(1, Int((minHeight / approxLineHeight).rounded(.down)))
        let maxLines = max(minLines, Int((maxHeight / approxLineHeight).rounded(.down)))

        return ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .textStyle(.body)
                    .foregroundStyle(Theme.foregroundTertiary)
                    .padding(.vertical, 9)
                    .padding(.horizontal, Spacing.md)
                    .allowsHitTesting(false)
            }

            TextField("", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(minLines ... maxLines)
                .textStyle(.body)
                .foregroundStyle(Theme.foregroundPrimary)
                .focused($isFocused)
                .onSubmit(onSubmit)
                .padding(.vertical, 9)
                .padding(.horizontal, Spacing.md)
        }
        .frame(minHeight: minHeight, maxHeight: maxHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(Theme.accent.opacity(isFocused ? 0.35 : 0), lineWidth: 2)
        )
    }
}

#Preview("SCAutosizeTextarea — light") {
    @Previewable @State var short = ""
    @Previewable @State var long = "The quick brown fox jumps over the lazy dog.\nSecond line here."

    return VStack(alignment: .leading, spacing: Spacing.md) {
        SCAutosizeTextarea(
            text: $short,
            placeholder: "Type a message…",
            onSubmit: {}
        )
        SCAutosizeTextarea(
            text: $long,
            placeholder: "Write something",
            onSubmit: {}
        )
    }
    .padding(Spacing.xl)
    .frame(width: 420)
    .background(Theme.background)
    .preferredColorScheme(.light)
}

#Preview("SCAutosizeTextarea — dark") {
    @Previewable @State var text = ""

    return VStack(alignment: .leading, spacing: Spacing.md) {
        SCAutosizeTextarea(
            text: $text,
            placeholder: "Reply to the agent…",
            onSubmit: {}
        )
    }
    .padding(Spacing.xl)
    .frame(width: 420)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
