import AppKit
import SwiftClawUI
import SwiftUI

/// Window chrome for the Perplexity-style SwiftClaw shell.
///
/// • Hides the title bar but keeps a fully-transparent titlebar area so the
///   traffic-light buttons remain visible and the user can drag the window.
/// • Inset traffic-light buttons by ~14pt to match the spacing in the
///   reference app.
/// • Adds a behind-window vibrancy view in dark mode so the rounded window
///   corners get a subtle glass texture.
struct PerplexityWindowChromeView: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { configure(v.window) }
        return v
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)
        window.minSize = NSSize(
            width: PXTheme.Layout.windowMinSize.width,
            height: PXTheme.Layout.windowMinSize.height
        )
        // Inset the traffic lights ~14pt down from the top edge.
        for btn in [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton),
        ] {
            guard let btn, let frame = btn.superview?.frame else { continue }
            var f = btn.frame
            // Re-anchor to give a 16pt top inset.
            f.origin.x = btn.tag == 0 ? 16 : f.origin.x // close stays at x=16 (default ~14)
            f.origin.y = frame.height - f.height - 16
            btn.frame = f
        }
    }
}

private struct PXVibrancyBackground: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underWindowBackground
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
        nsView.blendingMode = colorScheme == .dark ? .behindWindow : .withinWindow
        nsView.material = colorScheme == .dark ? .underWindowBackground : .windowBackground
    }
}

extension View {
    /// Apply the Perplexity-style chrome to the host `NSWindow`.
    func perplexityWindowChrome() -> some View {
        background(PXVibrancyBackground().ignoresSafeArea())
            .background(PerplexityWindowChromeView().frame(width: 0, height: 0))
    }
}
