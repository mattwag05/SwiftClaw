import SwiftClawCore
import SwiftUI

/// Perplexity-Computer-style composer.
///
/// A pill-shaped input with the prompt text on top and a horizontal row of
/// utility action icons + send button across the bottom. Used both in the
/// main chat surface and inside the floating Command Bar.
public struct PXComposer: View {
    @Binding public var text: String
    public var isGenerating: Bool
    public var sessionMode: SessionMode
    public var canvasOpen: Bool
    public var hasSession: Bool
    public var placeholder: String
    public var compact: Bool
    public var onSend: () -> Void
    public var onStop: () -> Void
    public var onModeChange: (SessionMode) -> Void
    public var onToggleCanvas: () -> Void

    @FocusState private var focused: Bool
    @AppStorage("sc.composerWebContext") private var webContext: Bool = false
    @AppStorage("sc.composerFontScale") private var composerFontScale: Double = 1.0
    @State private var showMentionPopover: Bool = false
    @State private var showVoicePopover: Bool = false
    @State private var showAttachPopover: Bool = false

    public init(
        text: Binding<String>,
        isGenerating: Bool,
        sessionMode: SessionMode = .chat,
        canvasOpen: Bool = false,
        hasSession: Bool = false,
        placeholder: String = "Ask anything…",
        compact: Bool = false,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onModeChange: @escaping (SessionMode) -> Void = { _ in },
        onToggleCanvas: @escaping () -> Void = {}
    ) {
        _text = text
        self.isGenerating = isGenerating
        self.sessionMode = sessionMode
        self.canvasOpen = canvasOpen
        self.hasSession = hasSession
        self.placeholder = placeholder
        self.compact = compact
        self.onSend = onSend
        self.onStop = onStop
        self.onModeChange = onModeChange
        self.onToggleCanvas = onToggleCanvas
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            // Text area — TextField with axis:.vertical auto-grows and
            // composes correctly with onKeyPress for Enter/Shift+Enter.
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($focused)
                .lineLimit(compact ? 1 ... 4 : 1 ... 8)
                .font(.system(size: 15 * composerFontScale, weight: .regular))
                .foregroundStyle(PXTheme.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .onKeyPress(.return, phases: .down) { event in
                    if event.modifiers.contains(.shift) { return .ignored }
                    if !isGenerating, !trimmed.isEmpty { onSend() }
                    return .handled
                }

            // Action row
            HStack(spacing: 4) {
                actionChip(icon: "paperclip", label: "Attach", action: { showAttachPopover.toggle() })
                    .popover(isPresented: $showAttachPopover, arrowEdge: .bottom) {
                        AttachPopoverView { snippet in
                            text = text.isEmpty ? snippet : text + "\n" + snippet
                            showAttachPopover = false
                        }
                    }
                actionChip(
                    icon: "globe",
                    label: webContext ? "Web context: on" : "Web context",
                    active: webContext,
                    action: { webContext.toggle() }
                )
                actionChip(icon: "at", label: "Mention", action: { showMentionPopover.toggle() })
                    .popover(isPresented: $showMentionPopover, arrowEdge: .bottom) {
                        MentionPopoverView { snippet in
                            text = text.isEmpty ? snippet : text + " " + snippet
                            showMentionPopover = false
                        }
                    }
                modeMenu
                if hasSession, sessionMode == .build {
                    actionChip(
                        icon: canvasOpen ? "rectangle.righthalf.filled" : "rectangle.righthalf",
                        label: "Canvas",
                        active: canvasOpen,
                        action: onToggleCanvas
                    )
                }
                Spacer()
                actionChip(
                    icon: "mic",
                    label: "Dictate (coming soon)",
                    action: { showVoicePopover.toggle() }
                )
                .popover(isPresented: $showVoicePopover, arrowEdge: .bottom) {
                    voicePlaceholderView
                }
                sendButton
            }
        }
        .padding(.horizontal, compact ? 14 : 16)
        .padding(.vertical, compact ? 12 : 14)
        .background(
            RoundedRectangle(cornerRadius: PXTheme.Radius.input, style: .continuous)
                .fill(PXTheme.surface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PXTheme.Radius.input, style: .continuous)
                .strokeBorder(PXTheme.borderHairline, lineWidth: 1)
        )
        .onAppear {
            // TextField focus needs to settle a tick after mount.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000)
                focused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pxFocusComposer)) { _ in
            focused = true
        }
        .animation(PXTheme.Motion.quick, value: trimmed.isEmpty)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var sendButton: some View {
        if isGenerating {
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PXTheme.onAccent)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(PXTheme.textSecondary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop generating")
        } else {
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(trimmed.isEmpty ? PXTheme.textTertiary : PXTheme.onAccent)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle().fill(trimmed.isEmpty ? PXTheme.surface2 : PXTheme.accent)
                    )
                    .scaleEffect(trimmed.isEmpty ? 1.0 : 1.04)
                    .shadow(
                        color: trimmed.isEmpty ? .clear : PXTheme.accent.opacity(0.4),
                        radius: trimmed.isEmpty ? 0 : 6,
                        y: 1
                    )
                    .animation(PXTheme.Motion.snap, value: trimmed.isEmpty)
            }
            .buttonStyle(.plain)
            .disabled(trimmed.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
            .accessibilityLabel("Send")
        }
    }

    private var modeMenu: some View {
        Menu {
            Button {
                onModeChange(.chat)
            } label: {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
            }
            Button {
                onModeChange(.build)
            } label: {
                Label("Build", systemImage: "hammer")
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: sessionMode == .build ? "hammer" : "bubble.left.and.bubble.right")
                    .font(.system(size: 11, weight: .medium))
                Text(sessionMode == .build ? "Build" : "Chat")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(PXTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: PXTheme.Radius.chip, style: .continuous)
                    .fill(PXTheme.surface2.opacity(0.6))
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var voicePlaceholderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "mic.slash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PXTheme.textSecondary)
                Text("Voice mode")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PXTheme.textPrimary)
            }
            Text("Hold-to-talk dictation isn't shipped yet. The composer accepts pasted text, files via the paperclip, and `@` mentions in the meantime.")
                .font(.system(size: 11.5))
                .foregroundStyle(PXTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Got it") { showVoicePopover = false }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 260)
    }

    private func actionChip(
        icon: String,
        label: String,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(active ? PXTheme.accent : PXTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: PXTheme.Radius.chip, style: .continuous)
                        .fill(active ? PXTheme.accentSoft : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
