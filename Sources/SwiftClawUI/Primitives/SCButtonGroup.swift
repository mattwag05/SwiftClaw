import SwiftUI

/// Segmented button group with a bound selection.
public struct SCButtonGroup<T: Hashable>: View {
    public struct Option: Identifiable {
        public let id: T
        public let label: String

        public init(id: T, label: String) {
            self.id = id
            self.label = label
        }
    }

    @Binding public var selection: T
    public let options: [Option]

    public init(selection: Binding<T>, options: [Option]) {
        _selection = selection
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                segment(option)
                if index < options.count - 1 {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: 1)
                }
            }
        }
        .frame(height: 32)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    @ViewBuilder
    private func segment(_ option: Option) -> some View {
        let isSelected = selection == option.id
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selection = option.id
            }
        } label: {
            Text(option.label)
                .textStyle(isSelected ? .bodyEmph : .body)
                .padding(.horizontal, Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isSelected ? Theme.accent.opacity(0.12) : Color.clear)
                .foregroundStyle(isSelected ? Theme.accentDeep : Theme.foregroundSecondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SCButtonGroupPreviewHost: View {
    @State private var selection: String = "write"

    var body: some View {
        SCButtonGroup(
            selection: $selection,
            options: [
                .init(id: "write", label: "Write"),
                .init(id: "code", label: "Code"),
                .init(id: "ask", label: "Ask"),
            ]
        )
        .frame(width: 320)
    }
}

#Preview("SCButtonGroup — light") {
    VStack(spacing: Spacing.md) {
        SCButtonGroupPreviewHost()
    }
    .padding(Spacing.xl)
    .background(Theme.background)
}

#Preview("SCButtonGroup — dark") {
    VStack(spacing: Spacing.md) {
        SCButtonGroupPreviewHost()
    }
    .padding(Spacing.xl)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
