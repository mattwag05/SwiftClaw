import SwiftClawUI
import SwiftUI

struct GeneralSettingsView: View {
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            Section("Backend") {
                Picker("Backend", selection: $vm.backendType) {
                    ForEach(BackendType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }

                TextField("Model ID", text: $vm.modelId)

                if viewModel.backendType == .http {
                    TextField("API URL", text: $vm.httpURL)
                    SecureField("API Key (optional)", text: $vm.httpAPIKey)
                }

                Button("Apply & Reload Backend") {
                    viewModel.backendState = .idle
                    Task { await viewModel.loadBackend() }
                }
            }
        }
        .formStyle(.grouped)
    }
}
