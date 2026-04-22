import SwiftUI

/// Menu-style picker with a chevron caret.
///
/// Wraps SwiftUI `Menu` so the control reads like a button: the trigger shows
/// the currently-selected option's label plus a `chevron.up.chevron.down`. The
/// optional `label` is rendered above the trigger in `captionEmph` style.
public struct SCCombobox<T: Hashable>: View {
    public struct Option: Identifiable {
        public let id: T
        public let label: String

        public init(id: T, label: String) {
            self.id = id
            self.label = label
        }
    }

    private let label: String?
    private let options: [Option]
    @Binding private var selection: T

    public init(
        _ label: String? = nil,
        selection: Binding<T>,
        options: [Option]
    ) {
        self.label = label
        _selection = selection
        self.options = options
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let label {
                Text(label)
                    .textStyle(.captionEmph)
                    .foregroundStyle(Theme.foregroundSecondary)
            }

            Menu {
                ForEach(options) { option in
                    Button {
                        selection = option.id
                    } label: {
                        if option.id == selection {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text(selectedLabel)
                        .textStyle(.body)
                        .foregroundStyle(Theme.foregroundPrimary)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.xs)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.foregroundSecondary)
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
                .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedLabel: String {
        options.first(where: { $0.id == selection })?.label ?? ""
    }
}

#Preview("SCCombobox — light") {
    @Previewable @State var model = "sonnet"
    @Previewable @State var count = 2

    let models: [SCCombobox<String>.Option] = [
        .init(id: "haiku", label: "Claude Haiku"),
        .init(id: "sonnet", label: "Claude Sonnet"),
        .init(id: "opus", label: "Claude Opus"),
    ]

    let counts: [SCCombobox<Int>.Option] = [
        .init(id: 1, label: "One"),
        .init(id: 2, label: "Two"),
        .init(id: 4, label: "Four"),
        .init(id: 8, label: "Eight"),
    ]

    return VStack(alignment: .leading, spacing: Spacing.lg) {
        SCCombobox("Model", selection: $model, options: models)
        SCCombobox("Parallel jobs", selection: $count, options: counts)
        SCCombobox(selection: $model, options: models)
    }
    .padding(Spacing.xl)
    .frame(width: 320)
    .background(Theme.background)
    .preferredColorScheme(.light)
}

#Preview("SCCombobox — dark") {
    @Previewable @State var model = "opus"

    let models: [SCCombobox<String>.Option] = [
        .init(id: "haiku", label: "Claude Haiku"),
        .init(id: "sonnet", label: "Claude Sonnet"),
        .init(id: "opus", label: "Claude Opus"),
    ]

    return VStack(alignment: .leading, spacing: Spacing.lg) {
        SCCombobox("Model", selection: $model, options: models)
    }
    .padding(Spacing.xl)
    .frame(width: 320)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
