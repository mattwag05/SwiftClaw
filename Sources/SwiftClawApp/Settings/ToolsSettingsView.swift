import SwiftClawUI
import SwiftUI

struct ToolsSettingsView: View {
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            Section("Require Approval") {
                if viewModel.toolApprovalOverrides.isEmpty {
                    Text("Start a chat to load tools.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.toolApprovalOverrides.keys.sorted(), id: \.self) { name in
                        Toggle(name, isOn: Binding(
                            get: { viewModel.toolApprovalOverrides[name] ?? false },
                            set: { vm.toolApprovalOverrides[name] = $0 }
                        ))
                    }
                }
                Text("Dangerous tools require approval by default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
