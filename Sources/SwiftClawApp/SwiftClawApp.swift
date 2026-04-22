import SwiftClawUI
import SwiftUI

@main
struct SwiftClawApp: App {
    @State private var viewModel = ChatViewModel()
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
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
        }

        Settings {
            SettingsView()
                .environment(viewModel)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
