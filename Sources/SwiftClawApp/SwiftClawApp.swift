import SwiftClawUI
import SwiftUI

@main
struct SwiftClawApp: App {
    @State private var viewModel = ChatViewModel()
    @State private var commandRegistry = CommandRegistry()
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .environment(commandRegistry)
                .preferredColorScheme(appearance.colorScheme)
        }
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    Task { await viewModel.newChat() }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Chat") {
                Button("Stop Generating") {
                    viewModel.cancelGeneration()
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!viewModel.isGenerating)
            }
            CommandMenu("View") {
                Button("Command Palette") {
                    commandRegistry.show()
                }
                .keyboardShortcut("k", modifiers: .command)
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
