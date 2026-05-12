import SwiftClawUI
import SwiftUI

/// First-run hint that teaches the user the "Press both ⌘ keys" gesture
/// (matches the Perplexity Computer onboarding frames).
///
/// State: `sc.hasSeenHotkeyHint` in `UserDefaults`. The hint disappears the
/// first time the command bar is summoned (via either path) and never
/// returns. Dismiss on click anywhere.
struct HotkeyHintOverlay: View {
    @AppStorage("sc.hasSeenHotkeyHint") private var hasSeen: Bool = false
    @State private var visible: Bool = false

    var body: some View {
        if visible {
            overlay
                .transition(.opacity)
                .onTapGesture {
                    dismiss()
                }
                .onReceive(NotificationCenter.default.publisher(for: .pxSummonCommandBar)) { _ in
                    dismiss()
                }
                .onAppear {
                    // Auto-fade after 30s so a user who never reads it isn't
                    // perpetually staring at the same hint pill.
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 30_000_000_000)
                        if visible { dismiss() }
                    }
                }
        } else if !hasSeen {
            Color.clear
                .onAppear {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        withAnimation(.easeOut(duration: 0.3)) { visible = true }
                    }
                }
        }
    }

    private var overlay: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                cmdKey
                Text("+")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))
                cmdKey
            }
            Text("Press both Command keys to summon from anywhere")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.20)
            }
        )
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        .padding(.bottom, 18)
    }

    private var cmdKey: some View {
        Image(systemName: "command")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.white.opacity(0.20), lineWidth: 1)
            )
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) { visible = false }
        hasSeen = true
    }
}
