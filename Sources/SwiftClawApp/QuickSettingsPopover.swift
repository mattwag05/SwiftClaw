import SwiftUI
import SwiftClawUI

struct QuickSettingsPopover: View {
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK SETTINGS")
                .font(.system(size: 10, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Backend", selection: $vm.backendType) {
                ForEach(BackendType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)

            TextField("Model ID", text: $vm.modelId)
                .textFieldStyle(.roundedBorder)

            if viewModel.backendType == .http {
                TextField("API URL", text: $vm.httpURL)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Temperature: \(String(format: "%.2f", viewModel.temperature))")
                    .font(.caption)
                Slider(value: $vm.temperature, in: 0...2, step: 0.05)
            }

            Button("Apply & Reload") {
                viewModel.backendState = .idle
                Task { await viewModel.loadBackend() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Divider()

            SettingsLink {
                HStack {
                    Text("Advanced Settings…")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 280)
    }
}
