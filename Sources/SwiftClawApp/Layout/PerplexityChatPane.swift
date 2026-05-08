import SwiftClawCore
import SwiftClawUI
import SwiftUI

/// Main chat surface for the Perplexity-style SwiftClaw app.
///
/// Empty state — centered SwiftClaw wordmark stacked above the composer.
/// Active state — transcript scrolls; composer pinned to bottom.
/// Build mode + canvas open — `HSplitView` with the canvas on the right.
struct PerplexityChatPane: View {
    @Environment(ChatViewModel.self) private var viewModel
    @State private var metrics = SystemMetricsMonitor()
    @AppStorage("sc.showSuggestionChips") private var showSuggestionChips: Bool = true
    @AppStorage("sc.useSerifWordmark") private var useSerifWordmark: Bool = true
}

private struct BlinkingDot: ViewModifier {
    @State private var dim = false
    func body(content: Content) -> some View {
        content
            .opacity(dim ? 0.3 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    dim = true
                }
            }
    }
}

extension PerplexityChatPane {
    var body: some View {
        Group {
            if viewModel.sessionMode == .build, viewModel.canvasOpen,
               let sessionId = viewModel.selectedSessionId
            {
                HSplitView {
                    paneBody()
                        .frame(minWidth: 420)
                    CanvasView(
                        sessionId: sessionId,
                        workspaceManager: viewModel.workspaceManager
                    )
                    .frame(minWidth: 320)
                }
            } else {
                paneBody()
            }
        }
        .background(PXTheme.chatBg)
    }

    @ViewBuilder
    private func paneBody() -> some View {
        @Bindable var vm = viewModel
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                topBar
                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    transcript
                    composerWell
                }
            }

            // First-run hotkey hint, anchored to the bottom.
            VStack {
                Spacer()
                HotkeyHintOverlay()
                Spacer().frame(height: 60)
            }
            .allowsHitTesting(true)

            // Backend overlays
            if case let .loading(progress) = viewModel.backendState {
                ModelLoadingOverlay(progress: progress)
            }
            if case let .error(msg) = viewModel.backendState {
                ErrorBannerView(message: msg) {
                    Task { await viewModel.loadBackend() }
                }
            }
        }
        .onAppear { metrics.start() }
        .onDisappear { metrics.stop() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            // Title slot — keeps space for traffic lights even though they live
            // on the window itself.
            if let title = viewModel.sessions.first(where: { $0.sessionId == viewModel.selectedSessionId })?.displayTitle, !viewModel.messages.isEmpty {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(PXTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 6)
            }
            Spacer()
            usageIndicator
            stopButton
            newThreadButton
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(height: 44, alignment: .top)
    }

    private var newThreadButton: some View {
        Button {
            Task { await viewModel.newChat() }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PXTheme.textSecondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(PXTheme.surface1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(PXTheme.borderHairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help("New thread (⌘N)")
    }

    @ViewBuilder
    private var usageIndicator: some View {
        let usage = viewModel.contextUsage
        let pct = Int(Double(usage.used) / Double(max(1, usage.total)) * 100)
        HStack(spacing: 4) {
            Circle()
                .fill(pct > 80 ? PXTheme.warning : PXTheme.accent)
                .frame(width: 6, height: 6)
            Text("\(usage.isApproximate ? "~" : "")\(pct)%")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(PXTheme.textTertiary)
        }
        .help("\(usage.used) / \(usage.total) tokens")
    }

    @ViewBuilder
    private var stopButton: some View {
        if viewModel.isGenerating {
            Button {
                viewModel.cancelGeneration()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(PXTheme.danger))
            }
            .buttonStyle(.plain)
            .help("Stop")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        @Bindable var vm = viewModel
        return VStack(spacing: 0) {
            Spacer(minLength: 12)
            if useSerifWordmark {
                PXWordmark(tier: tierLabel)
            } else {
                Text("SwiftClaw")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(PXTheme.textSecondary)
            }
            modelByline
                .padding(.bottom, 44)
                .padding(.top, 6)
            PXComposer(
                text: $vm.inputText,
                isGenerating: viewModel.isGenerating,
                sessionMode: viewModel.sessionMode,
                canvasOpen: viewModel.canvasOpen,
                hasSession: viewModel.selectedSessionId != nil,
                placeholder: "Ask anything…",
                onSend: { viewModel.send() },
                onStop: { viewModel.cancelGeneration() },
                onAttach: {},
                onModeChange: { vm.sessionMode = $0 },
                onToggleCanvas: { vm.canvasOpen.toggle() }
            )
            .frame(maxWidth: PXTheme.Layout.composerMaxWidth)
            keyboardHint
                .padding(.top, 6)
                .padding(.bottom, 16)
            if showSuggestionChips {
                suggestionRow
            }
            Spacer(minLength: 80)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var keyboardHint: some View {
        HStack(spacing: 12) {
            shortcut("↩", "send")
            shortcut("⇧↩", "newline")
            shortcut("⌃⌘P", "summon")
        }
        .frame(maxWidth: PXTheme.Layout.composerMaxWidth, alignment: .center)
    }

    private func shortcut(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(PXTheme.textTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(PXTheme.surface1.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(PXTheme.borderHairline, lineWidth: 0.5)
                )
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(PXTheme.textTertiary.opacity(0.85))
        }
    }

    private var suggestionRow: some View {
        let suggestions: [(String, String)] = viewModel.sessionMode == .build
            ? [
                ("hammer", "Build a hello world page"),
                ("doc.text", "Write a Python script"),
                ("paintbrush", "Make a simple game"),
            ]
            : [
                ("desktopcomputer", "What's my system info?"),
                ("internaldrive", "Show disk usage"),
                ("clock", "What time is it?"),
            ]
        return HStack(spacing: 8) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { _, s in
                SuggestionChip(icon: s.0, label: s.1) {
                    viewModel.sendSuggestion(s.1)
                }
            }
        }
    }

    private var tierLabel: String? {
        if viewModel.backendType == .mlx { return "on-device" }
        return nil
    }

    private var modelByline: some View {
        let backendName = viewModel.backendType == .mlx ? "MLX" : "Ollama"
        let modelShort = viewModel.modelId
            .components(separatedBy: "/")
            .last ?? viewModel.modelId
        return HStack(spacing: 6) {
            statusDot
            Text(modelShort)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(PXTheme.textTertiary)
            Text("·")
                .foregroundStyle(PXTheme.textTertiary.opacity(0.5))
            Text(backendStateLabel(backendName))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(PXTheme.textTertiary)
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        switch viewModel.backendState {
        case .ready:
            Circle().fill(PXTheme.success).frame(width: 5, height: 5)
        case .loading:
            Circle()
                .fill(PXTheme.warning)
                .frame(width: 5, height: 5)
                .modifier(BlinkingDot())
        case .error:
            Circle().fill(PXTheme.danger).frame(width: 5, height: 5)
        case .idle:
            Circle().fill(PXTheme.textTertiary).frame(width: 5, height: 5)
        }
    }

    private func backendStateLabel(_ backendName: String) -> String {
        switch viewModel.backendState {
        case .ready: return backendName
        case .loading: return "loading…"
        case .error: return "\(backendName) · error"
        case .idle: return "\(backendName) · idle"
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        GemmaMessageList(
            messages: viewModel.messages,
            onApproveToolCall: { callId in viewModel.approveToolCall(callId: callId) },
            onDenyToolCall: { callId in viewModel.denyToolCall(callId: callId) },
            onCopyBubble: { bubble in viewModel.copyBubble(bubble) },
            onRegenerateBubble: { _ in viewModel.regenerate() }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var composerWell: some View {
        @Bindable var vm = viewModel
        return VStack(spacing: 0) {
            PXComposer(
                text: $vm.inputText,
                isGenerating: viewModel.isGenerating,
                sessionMode: viewModel.sessionMode,
                canvasOpen: viewModel.canvasOpen,
                hasSession: viewModel.selectedSessionId != nil,
                placeholder: "Ask a follow-up…",
                compact: true,
                onSend: { viewModel.send() },
                onStop: { viewModel.cancelGeneration() },
                onAttach: {},
                onModeChange: { vm.sessionMode = $0 },
                onToggleCanvas: { vm.canvasOpen.toggle() }
            )
            .frame(maxWidth: PXTheme.Layout.composerMaxWidth)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [PXTheme.chatBg.opacity(0), PXTheme.chatBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)
            .frame(maxHeight: .infinity, alignment: .top)
        )
    }
}
