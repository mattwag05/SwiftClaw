import SwiftUI

public struct InputBarView: View {
    @Binding public var text: String
    public let isGenerating: Bool
    public let onSend: () -> Void
    public let onStop: () -> Void

    @FocusState private var focused: Bool

    public init(
        text: Binding<String>,
        isGenerating: Bool,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self._text = text
        self.isGenerating = isGenerating
        self.onSend = onSend
        self.onStop = onStop
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask anything…", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit { onSend() }
                .padding(Theme.inputPadding)
                .background(Theme.inputBackground, in: RoundedRectangle(cornerRadius: Theme.inputCornerRadius))

            if isGenerating {
                Button(action: onStop) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.errorColor)
                }
                .buttonStyle(.plain)
                .frame(minWidth: Theme.minimumControlSize, minHeight: Theme.minimumControlSize)
                .accessibilityLabel("Stop generating")
            } else {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(trimmed.isEmpty ? Theme.secondaryForeground : Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(trimmed.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
                .frame(minWidth: Theme.minimumControlSize, minHeight: Theme.minimumControlSize)
                .accessibilityLabel("Send message")
            }
        }
        .padding(Theme.containerPadding)
        .onAppear { focused = true }
    }
}
