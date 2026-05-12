import AppKit
import SwiftClawUI
import SwiftUI

// MARK: - Window accessor

/// Applies the Gemma Chat window chrome to the host NSWindow:
///   • Hidden title bar + transparent title bar area
///   • Traffic-light buttons shifted to Y=−14 (custom vertical alignment)
///   • In dark mode: NSVisualEffectView(.underWindowBackground) behind content
///   • In light mode: plain solid background (vibrancy looks wrong in light)
struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(
            width: GemmaLayout.windowMinSize.width,
            height: GemmaLayout.windowMinSize.height
        )

        // Shift traffic lights to match Gemma Chat's `trafficLightPosition`.
        for btn in [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton),
        ] {
            guard let btn else { continue }
            var frame = btn.frame
            frame.origin.y -= 2   // subtle downward nudge to match Gemma's Y=14
            btn.frame = frame
        }
    }
}

// MARK: - Vibrancy background view

/// Full-window vibrancy in dark mode, plain surface in light.
struct VibrancyWindowBackground: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underWindowBackground
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // In light mode disable blending so we get a solid background.
        nsView.blendingMode = colorScheme == .dark ? .behindWindow : .withinWindow
        nsView.material = colorScheme == .dark ? .underWindowBackground : .windowBackground
    }
}

// MARK: - View modifier convenience

public extension View {
    /// Applies the Gemma Chat window chrome: hidden titlebar + adaptive vibrancy.
    func gemmaWindowChrome() -> some View {
        self
            .background(VibrancyWindowBackground().ignoresSafeArea())
            .background(WindowChrome().frame(width: 0, height: 0))
    }
}
