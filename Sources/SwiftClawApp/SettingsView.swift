import SwiftClawUI
import SwiftUI

/// The Settings scene. A two-column `NavigationSplitView` with a sidebar of
/// categories on the left and the selected pane on the right.
struct SettingsView: View {
    @State private var selection: SettingsCategory = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsCategory.allCases, selection: $selection) { category in
                Label(category.label, systemImage: category.iconSystemName)
                    .tag(category)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            detail(for: selection)
                .frame(minWidth: 360, idealWidth: 460, maxWidth: .infinity,
                       minHeight: 360, idealHeight: 520, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 680, minHeight: 440)
    }

    @ViewBuilder
    private func detail(for category: SettingsCategory) -> some View {
        switch category {
        case .general: GeneralSettingsView()
        case .model: ModelSettingsView()
        case .tools: ToolsSettingsView()
        case .memory: MemorySettingsView()
        case .appearance: AppearanceSettingsView()
        case .about: AboutSettingsView()
        }
    }
}
