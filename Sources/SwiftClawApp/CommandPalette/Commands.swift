import AppKit
import Foundation
import SwiftClawUI

/// Builds the full set of `SCCommand.Item`s for the ⌘K palette.
///
/// Reads live state from `ChatViewModel` and composes callbacks that end by
/// invoking `onDismiss` so the palette closes after any action runs.
@MainActor
enum Commands {
    static func all(
        viewModel: ChatViewModel,
        onOpenSettings: @escaping () -> Void,
        onToggleSidebar: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> [SCCommand.Item] {
        var items: [SCCommand.Item] = []

        // MARK: Navigation

        items.append(.init(
            id: "nav.newChat",
            title: "New Chat",
            subtitle: "Navigation",
            icon: "square.and.pencil",
            shortcut: "⌘N",
            action: {
                Task {
                    await viewModel.newChat()
                    onDismiss()
                }
            }
        ))

        items.append(.init(
            id: "nav.openSettings",
            title: "Open Settings",
            subtitle: "Navigation",
            icon: "gearshape",
            shortcut: "⌘,",
            action: {
                onOpenSettings()
                onDismiss()
            }
        ))

        items.append(.init(
            id: "nav.toggleSidebar",
            title: "Toggle Sidebar",
            subtitle: "Navigation",
            icon: "sidebar.left",
            shortcut: "⌘\\",
            action: {
                onToggleSidebar()
                onDismiss()
            }
        ))

        items.append(.init(
            id: "nav.summonCommandBar",
            title: "Summon Command Bar",
            subtitle: "Navigation",
            icon: "command.circle",
            shortcut: "⌃⌘P",
            action: {
                NotificationCenter.default.post(name: .pxSummonCommandBar, object: nil)
                onDismiss()
            }
        ))

        items.append(.init(
            id: "nav.focusComposer",
            title: "Focus Composer",
            subtitle: "Navigation",
            icon: "text.cursor",
            shortcut: "⌘L",
            action: {
                NotificationCenter.default.post(name: .pxFocusComposer, object: nil)
                onDismiss()
            }
        ))

        items.append(.init(
            id: "nav.toggleTheme",
            title: "Toggle Theme",
            subtitle: "Navigation",
            icon: "circle.lefthalf.filled",
            action: {
                cycleAppearance()
                onDismiss()
            }
        ))

        items.append(.init(
            id: "nav.quit",
            title: "Quit SwiftClaw",
            subtitle: "Navigation",
            icon: "power",
            shortcut: "⌘Q",
            action: {
                NSApplication.shared.terminate(nil)
                onDismiss()
            }
        ))

        // MARK: Agent

        if viewModel.isGenerating {
            items.append(.init(
                id: "agent.stop",
                title: "Stop Generation",
                subtitle: "Agent",
                icon: "stop.circle",
                shortcut: "⌘.",
                action: {
                    viewModel.cancelGeneration()
                    onDismiss()
                }
            ))
        }

        items.append(.init(
            id: "agent.clearContext",
            title: "Clear Context",
            subtitle: "Agent",
            icon: "trash",
            action: {
                Task {
                    await viewModel.newChat()
                    onDismiss()
                }
            }
        ))

        if let lastUserText = lastUserMessageText(in: viewModel) {
            items.append(.init(
                id: "agent.rerun",
                title: "Re-run last turn",
                subtitle: "Agent",
                icon: "arrow.clockwise",
                action: {
                    viewModel.sendSuggestion(lastUserText)
                    onDismiss()
                }
            ))
        }

        // MARK: Recent threads

        for summary in viewModel.sessions.prefix(8) {
            items.append(.init(
                id: "thread.\(summary.sessionId)",
                title: summary.displayTitle,
                subtitle: "Thread",
                icon: summary.isPinned ? "pin.fill" : "tray",
                action: {
                    viewModel.selectedSessionId = summary.sessionId
                    onDismiss()
                }
            ))
        }

        return items
    }

    // MARK: - Helpers

    /// Cycle through the three `AppAppearance` cases by reading/writing
    /// `UserDefaults` directly — `@AppStorage` property wrappers cannot be
    /// used inside a plain function body.
    private static func cycleAppearance() {
        let ud = UserDefaults.standard
        let current = ud.string(forKey: AppAppearance.storageKey)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
        let next: AppAppearance
        switch current {
        case .system: next = .light
        case .light: next = .dark
        case .dark: next = .system
        }
        ud.set(next.rawValue, forKey: AppAppearance.storageKey)
    }

    /// Walk `messages` in reverse to find the most recent `.user` bubble's text.
    private static func lastUserMessageText(in viewModel: ChatViewModel) -> String? {
        for bubble in viewModel.messages.reversed() {
            if case let .user(text) = bubble.kind, !text.isEmpty {
                return text
            }
        }
        return nil
    }
}
