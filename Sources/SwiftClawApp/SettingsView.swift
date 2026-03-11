import SwiftUI
import SwiftClawUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }
            ModelSettingsTab()
                .tabItem { Label("Model", systemImage: "slider.horizontal.3") }
            AdaptersSettingsTab()
                .tabItem { Label("Adapters", systemImage: "cpu") }
            MemorySettingsTab()
                .tabItem { Label("Memory", systemImage: "brain") }
            ToolsSettingsTab()
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 520, height: 360)
        .padding()
    }
}

struct GeneralSettingsTab: View {
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel
        Form {
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
        .formStyle(.grouped)
    }
}

struct ModelSettingsTab: View {
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            Slider(value: $vm.temperature, in: 0...2, step: 0.05) {
                Text("Temperature (\(String(format: "%.2f", viewModel.temperature)))")
            }

            Stepper("Max Tokens: \(viewModel.maxTokens)", value: $vm.maxTokens, in: 256...16384, step: 256)
        }
        .formStyle(.grouped)
    }
}

struct AdaptersSettingsTab: View {
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            Toggle("Auto-select best adapter", isOn: $vm.autoAdapter)

            if !viewModel.autoAdapter {
                Picker("Adapter", selection: $vm.selectedAdapter) {
                    Text("None (base model)").tag(String?.none)
                    ForEach(viewModel.adapters, id: \.name) { adapter in
                        Text(adapter.name).tag(Optional(adapter.name))
                    }
                }
            }

            Button("Refresh") {
                Task { await viewModel.refreshAdapters() }
            }

            if viewModel.adapters.isEmpty {
                Text("No adapters found. Train one with `swiftclaw train`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct ToolsSettingsTab: View {
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
            }
            Text("Dangerous tools require approval by default. Toggle to override.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

struct MemorySettingsTab: View {
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            Toggle("Enable agent memory", isOn: $vm.memoryEnabled)

            if viewModel.memoryEnabled {
                Text("Memory is stored at ~/.swiftclaw/memory/SysopAgent.json")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
