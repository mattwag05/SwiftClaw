import SwiftUI

/// Auto-growing composer bar with send/stop toggle.
/// Drop-in replacement for `InputBarView` with the same public interface.
public struct GemmaComposer: View {
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

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask anything…", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($focused)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .onKeyPress(.return, phases: .down) { event in
                    if event.modifiers.contains(.command) {
                        if !isGenerating && !trimmed.isEmpty { onSend() }
                        return .handled
                    }
                    return .ignored
                }

            actionButton
        }
        .background(
            RoundedRectangle(cornerRadius: GemmaRadius.lg)
                .fill(Surface.s04)
                .overlay(
                    RoundedRectangle(cornerRadius: GemmaRadius.lg)
                        .strokeBorder(GemmaBorder.subtle, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onAppear { focused = true }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isGenerating {
            Button(action: onStop) {
                Image(systemName: "square.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(GemmaForeground.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: GemmaRadius.sm))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 7)
            .padding(.trailing, 8)
            .accessibilityLabel("Stop generating")
        } else {
            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(trimmed.isEmpty ? GemmaForeground.tertiary : .white)
                    .frame(width: 28, height: 28)
                    .background(trimmed.isEmpty ? Surface.s08 : Theme.brandBlue)
                    .clipShape(RoundedRectangle(cornerRadius: GemmaRadius.sm))
            }
            .buttonStyle(.plain)
            .disabled(trimmed.isEmpty)
            .padding(.bottom, 7)
            .padding(.trailing, 8)
            .accessibilityLabel("Send message")
            .animation(.gemmaQuick, value: trimmed.isEmpty)
        }
    }
}
