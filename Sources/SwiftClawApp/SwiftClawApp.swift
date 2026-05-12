import AppKit
import SwiftClawUI
import SwiftUI

@main
struct SwiftClawApp: App {
    @State private var viewModel = ChatViewModel()
    @State private var commandRegistry = CommandRegistry()
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .dark
    @NSApplicationDelegateAdaptor(SwiftClawAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            PerplexityRoot()
                .environment(viewModel)
                .environment(commandRegistry)
                .preferredColorScheme(appearance.colorScheme)
                .perplexityWindowChrome()
                .onAppear {
                    appDelegate.attach(viewModel: viewModel)
                }
        }
        .defaultSize(
            width: PXTheme.Layout.windowDefaultSize.width,
            height: PXTheme.Layout.windowDefaultSize.height
        )
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Thread") {
                    Task { await viewModel.newChat() }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Thread") {
                Button("Stop Generating") {
                    viewModel.cancelGeneration()
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!viewModel.isGenerating)

                Divider()

                Button("Summon Command Bar") {
                    appDelegate.summonCommandBar()
                }
                .keyboardShortcut("p", modifiers: [.command, .control])
            }
            CommandMenu("View") {
                Button("Command Palette") {
                    commandRegistry.show()
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .pxToggleSidebar, object: nil)
                }
                .keyboardShortcut("\\", modifiers: .command)

                Button("Focus Composer") {
                    NotificationCenter.default.post(name: .pxFocusComposer, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(viewModel)
                .environment(commandRegistry)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}

// MARK: - App delegate (owns the global hotkey monitor + command bar)

@MainActor
final class SwiftClawAppDelegate: NSObject, NSApplicationDelegate {
    private weak var viewModel: ChatViewModel?

    func applicationDidFinishLaunching(_: Notification) {
        GlobalHotkeyMonitor.shared.onTrigger = { [weak self] in
            self?.summonCommandBar()
        }
        GlobalHotkeyMonitor.shared.start()
        NotificationCenter.default.addObserver(
            forName: .pxSummonCommandBar,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.summonCommandBar() }
        }
    }

    func applicationWillTerminate(_: Notification) {
        GlobalHotkeyMonitor.shared.stop()
    }

    func attach(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    func summonCommandBar() {
        guard let viewModel else { return }
        CommandBarController.shared.toggle {
            PerplexityCommandBar(onDismiss: {
                CommandBarController.shared.hide()
            })
            .environment(viewModel)
        }
    }
}
