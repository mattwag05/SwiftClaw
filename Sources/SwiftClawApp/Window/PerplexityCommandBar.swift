import SwiftClawCore
import SwiftClawUI
import SwiftUI

/// Floating command bar shown when the global hotkey fires.
///
/// Mirrors Perplexity Computer's "press both Command keys" surface and
/// the follow-on status pill (matches video frames 25, 37–42):
///
///   1. **Idle** — composer pill with "Start a task…" prompt.
///   2. **Working** — collapsed status pill with a pulsing dot + first
///      streaming chars of the response.
///   3. **Done** — short result preview + "Open in SwiftClaw" affordance.
///
/// The bar transforms in place; the controller resizes the host panel to
/// match each phase.
struct PerplexityCommandBar: View {
    @Environment(ChatViewModel.self) private var viewModel
    @State private var localText: String = ""
    @State private var phase: Phase = .idle
    @State private var preview: String = ""
    @State private var pendingTask: Task<Void, Never>?
    let onDismiss: () -> Void

    enum Phase: Equatable {
        case idle
        case working
        case done
    }

    var body: some View {
        Group {
            switch phase {
            case .idle: idleBar
            case .working: workingPill
            case .done: donePill
            }
        }
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.18)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: phase == .idle ? 22 : 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: phase == .idle ? 22 : 16, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 30, y: 14)
        .animation(PXTheme.Motion.snap, value: phase)
        .onChange(of: viewModel.isGenerating) { _, generating in
            if !generating, phase == .working {
                phase = .done
                pendingTask?.cancel()
                // Auto-dismiss the done pill after a short pause.
                pendingTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 4_500_000_000)
                    onDismiss()
                }
            }
        }
        .onChange(of: viewModel.streamingContentVersion) { _, _ in
            // streamingContentVersion fires on every chunk during generation.
            // Skip the work when the bar isn't actively rendering progress.
            guard phase == .working else { return }
            updatePreview()
        }
    }

    // MARK: - Phase bodies

    private var idleBar: some View {
        PXComposer(
            text: $localText,
            isGenerating: false,
            sessionMode: viewModel.sessionMode,
            canvasOpen: false,
            hasSession: viewModel.selectedSessionId != nil,
            placeholder: "Start a task…",
            compact: true,
            onSend: send,
            onStop: {},
            onModeChange: { viewModel.sessionMode = $0 },
            onToggleCanvas: {}
        )
        .padding(14)
        .frame(width: PXTheme.Layout.commandBarSize.width)
    }

    private var workingPill: some View {
        HStack(spacing: 12) {
            pulseDot
            VStack(alignment: .leading, spacing: 1) {
                Text("Working…")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(0.4)
                    .textCase(.uppercase)
                Text(preview.isEmpty ? "Thinking" : preview)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button(action: openInMainWindow) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Open in SwiftClaw")
            stopButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(width: PXTheme.Layout.commandBarSize.width * 0.78)
    }

    private var donePill: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PXTheme.success)
            VStack(alignment: .leading, spacing: 1) {
                Text("Done")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(0.4)
                    .textCase(.uppercase)
                Text(preview.isEmpty ? "Task complete" : preview)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button(action: openInMainWindow) {
                Text("Open")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(width: PXTheme.Layout.commandBarSize.width * 0.78)
    }

    // MARK: - Sub-elements

    private var pulseDot: some View {
        Circle()
            .fill(PXTheme.accent)
            .frame(width: 10, height: 10)
            .modifier(PulseAnimation())
    }

    private var stopButton: some View {
        Button {
            viewModel.cancelGeneration()
            phase = .done
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .help("Stop")
    }

    // MARK: - Actions

    private func send() {
        let prompt = localText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        localText = ""
        preview = ""
        phase = .working
        viewModel.send(prompt: prompt)
    }

    private func openInMainWindow() {
        for w in NSApp.windows {
            if w.canBecomeKey, w.styleMask.contains(.titled) {
                w.makeKeyAndOrderFront(nil)
                break
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        onDismiss()
    }

    private func updatePreview() {
        // Pull the latest assistant chunk for the floating preview.
        if let last = viewModel.messages.last {
            switch last.kind {
            case let .streamingAssistant(text, _, _):
                preview = String(text.suffix(140)).trimmingCharacters(in: .whitespacesAndNewlines)
            case let .assistant(text):
                preview = String(text.prefix(140)).trimmingCharacters(in: .whitespacesAndNewlines)
            default:
                break
            }
        }
    }
}

// MARK: - Pulse animation

private struct PulseAnimation: ViewModifier {
    @State private var phase: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(phase ? 0.4 : 1.0)
            .scaleEffect(phase ? 0.85 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    phase = true
                }
            }
    }
}

/// `NSVisualEffectView` bridge for SwiftUI.
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
