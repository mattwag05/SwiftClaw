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

                if viewModel.availableModels.isEmpty {
                    TextField("Model ID", text: $vm.modelId)
                } else {
                    Picker("Model", selection: $vm.modelId) {
                        ForEach(viewModel.availableModels) { model in
                            Text(model.id).tag(model.id)
                        }
                    }
                    .onChange(of: viewModel.modelId) { _, newId in
                        Task { await viewModel.fetchModelInfo(for: newId) }
                    }
                }

                if viewModel.backendType == .http {
                    TextField("API URL", text: $vm.httpURL)
                    SecureField("API Key (optional)", text: $vm.httpAPIKey)
                }

                if let ctx = viewModel.discoveredContextWindow {
                    LabeledContent("Context Window", value: "\(ctx.formatted()) tokens")
                }

                Button("Apply & Reload Backend") {
                    viewModel.backendState = .idle
                    Task { await viewModel.loadBackend() }
                }
            }
        }
        .formStyle(.grouped)
        .task { await viewModel.discoverModels() }
    }
}
