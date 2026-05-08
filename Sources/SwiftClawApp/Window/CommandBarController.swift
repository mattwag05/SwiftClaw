import AppKit
import SwiftClawUI
import SwiftUI

/// Manages the lifecycle of the floating Command Bar window.
///
/// The bar is a borderless `NSPanel` that floats over all spaces, takes
/// keyboard focus while visible, and dismisses on Escape or click-outside.
/// Summoned by `GlobalHotkeyMonitor` (double-Command tap by default).
@MainActor
final class CommandBarController {
    static let shared = CommandBarController()

    private var panel: NSPanel?
    private var localMonitor: Any?

    /// Toggle the command bar's visibility, attaching the supplied SwiftUI body
    /// the first time it's shown. The `getViewModel` closure runs on each show
    /// so the bar always reflects the latest view-model instance.
    func toggle<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        if panel?.isVisible == true {
            hide()
        } else {
            show(content: content)
        }
    }

    func show<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        let panel = ensurePanel()

        let host = NSHostingController(
            rootView: AnyView(content().environment(\.colorScheme, .dark))
        )
        panel.contentViewController = host

        // Center on the active screen, slightly above center.
        if let screen = NSScreen.main {
            let size = PXTheme.Layout.commandBarSize
            let frame = screen.visibleFrame
            let x = frame.midX - size.width / 2
            let y = frame.midY + frame.height / 6 - size.height / 2
            panel.setFrame(
                NSRect(x: x, y: y, width: size.width, height: size.height),
                display: true
            )
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Dismiss on Escape — local monitor catches it before reaching the editor.
        installLocalMonitor()
    }

    func hide() {
        panel?.orderOut(nil)
        removeLocalMonitor()
    }

    private func ensurePanel() -> NSPanel {
        if let p = panel { return p }
        let p = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: PXTheme.Layout.commandBarSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .modalPanel
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.hidesOnDeactivate = true
        p.becomesKeyOnlyIfNeeded = false
        panel = p
        return p
    }

    private func installLocalMonitor() {
        if localMonitor != nil { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // 53 = Escape
            if event.keyCode == 53 {
                self.hide()
                return nil
            }
            return event
        }
    }

    private func removeLocalMonitor() {
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
    }
}

/// `NSPanel` subclass that can become key & first responder despite being
/// borderless. Required so the embedded `TextEditor` accepts keystrokes.
private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
