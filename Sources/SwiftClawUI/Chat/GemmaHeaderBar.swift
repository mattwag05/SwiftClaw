import SwiftUI
import SwiftClawCore

/// Header bar for the chat detail view.
public struct GemmaHeaderBar: View {
    public let title: String?
    @Binding public var mode: SessionMode
    @Binding public var canvasOpen: Bool
    public let hasSession: Bool

    public init(
        title: String?,
        mode: Binding<SessionMode>,
        canvasOpen: Binding<Bool>,
        hasSession: Bool
    ) {
        self.title = title
        self._mode = mode
        self._canvasOpen = canvasOpen
        self.hasSession = hasSession
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Left: title
            Text(title ?? "SwiftClaw")
                .font(.headline)
                .foregroundStyle(GemmaForeground.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)

            // Center: mode picker (only when a session is selected)
            if hasSession {
                Picker("Mode", selection: $mode) {
                    ForEach(SessionMode.allCases, id: \.self) { m in
                        Text(m.rawValue.capitalized).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .animation(.gemmaQuick, value: mode)
            }

            // Right: canvas toggle (build mode only)
            HStack {
                if hasSession && mode == .build {
                    Button {
                        withAnimation(.gemmaSnap) { canvasOpen.toggle() }
                    } label: {
                        Image(systemName: canvasOpen ? "eye.slash" : "eye")
                            .font(.system(size: 14))
                            .foregroundStyle(canvasOpen ? Theme.brandBlue : GemmaForeground.secondary)
                            .frame(width: 28, height: 28)
                            .background(canvasOpen ? Theme.brandBlue.opacity(0.12) : Surface.s04)
                            .clipShape(RoundedRectangle(cornerRadius: GemmaRadius.sm))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(canvasOpen ? "Hide canvas" : "Show canvas")
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 16)
            .animation(.gemmaQuick, value: mode)
        }
        .frame(height: GemmaLayout.headerHeight)
        .background(GemmaBackground.window)
        .overlay(alignment: .bottom) {
            Divider()
                .foregroundStyle(GemmaBorder.subtle)
        }
    }
}
