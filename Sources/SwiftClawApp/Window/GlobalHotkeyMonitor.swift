import AppKit
import Carbon.HIToolbox
import Foundation

/// Detects the "press both Command keys" gesture used by Perplexity Computer
/// to summon its command bar.
///
/// Implementation: a global Carbon event tap on the modifier-changed event.
/// The gesture is "press and release left-Command twice within `interval`"
/// (or right-Command — either side works). We also expose a fallback hotkey
/// (default ⌥⌘Space) that is registered system-wide via Carbon's
/// `RegisterEventHotKey` so the user can summon the bar without the gesture.
@MainActor
final class GlobalHotkeyMonitor {
    static let shared = GlobalHotkeyMonitor()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hotkeyRef: EventHotKeyRef?
    private var hotkeyHandlerRef: EventHandlerRef?
    private var lastCommandTap: Date?
    private let doubleTapWindow: TimeInterval = 0.32

    /// Called when either the gesture or the fallback hotkey fires.
    var onTrigger: (@MainActor () -> Void)?

    /// Whether the double-Command gesture detector is functional. Requires
    /// the host process to have Accessibility permissions; the Carbon hotkey
    /// works without them.
    var isGestureDetectorAvailable: Bool {
        AXIsProcessTrusted()
    }

    func start() {
        installModifierMonitor()
        registerFallbackHotkey()
    }

    /// Triggers macOS to prompt for Accessibility access if the host process
    /// doesn't already have it. Safe to call on every launch.
    static func requestAccessibilityIfNeeded() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let ref = hotkeyRef { UnregisterEventHotKey(ref); hotkeyRef = nil }
        if let h = hotkeyHandlerRef { RemoveEventHandler(h); hotkeyHandlerRef = nil }
    }

    // MARK: - Double-Command tap detector

    private func installModifierMonitor() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            // Treat both .command and a raw modifier flags change as candidates.
            let flags = event.modifierFlags
            let cmdActive = flags.contains(.command)
            // We only care about transitions where Command is the *only* mod
            // that just changed (no Shift / Option / Control).
            let onlyCmdChanged: Bool = {
                let interesting: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
                let intersected = flags.intersection(interesting)
                return intersected == .command || intersected.isEmpty
            }()
            guard onlyCmdChanged else { return }

            if !cmdActive {
                // Released — count toward double-tap.
                let now = Date()
                if let last = self.lastCommandTap, now.timeIntervalSince(last) < self.doubleTapWindow {
                    self.lastCommandTap = nil
                    Task { @MainActor in self.onTrigger?() }
                } else {
                    self.lastCommandTap = now
                }
            }
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            handler(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handler(event)
            return event
        }
    }

    // MARK: - Fallback Carbon hotkey (⌃⌘P)

    //
    // Avoid ⌥⌘Space (Finder's "Show Find") and ⌃⌥Space (Spotlight File search
    // on some setups) — the system-level binding wins over our app handler.

    private func registerFallbackHotkey() {
        let hotkeyID = EventHotKeyID(signature: OSType(0x5357_4354 /* "SWCT" */ ), id: 1)
        var ref: EventHotKeyRef?
        // P = kVK_ANSI_P = 35; Control + Cmd
        let modifiers = UInt32(cmdKey | controlKey)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotkeyRef = ref
            installHotkeyHandler()
        }
    }

    private func installHotkeyHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData -> OSStatus in
                guard let userData, let _ = eventRef else { return noErr }
                let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in monitor.onTrigger?() }
                return noErr
            },
            1,
            &spec,
            userData,
            &hotkeyHandlerRef
        )
    }
}
