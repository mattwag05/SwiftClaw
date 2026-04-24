import SwiftClawCore
import SwiftClawUI
import SwiftUI

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

            // Model picker — shows discovered models with text-field fallback
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Model")
                        .font(.system(size: 10, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if viewModel.isDiscoveringModels {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    } else {
                        Button {
                            Task { await viewModel.discoverModels() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Refresh models")
                    }
                }

                if viewModel.availableModels.isEmpty {
                    TextField("Model ID", text: $vm.modelId)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SCCombobox(
                        selection: $vm.modelId,
                        options: viewModel.availableModels.map { model in
                            SCCombobox<String>.Option(
                                id: model.id,
                                label: formatModelLabel(model)
                            )
                        }
                    )
                    .onChange(of: viewModel.modelId) { _, newId in
                        Task { await viewModel.fetchModelInfo(for: newId) }
                    }
                }

                if let ctx = viewModel.discoveredContextWindow {
                    Text("Context: \(ctx.formatted()) tokens")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 280)
    }

    private func formatModelLabel(_ model: DiscoveredModel) -> String {
        var parts = [model.id.components(separatedBy: "/").last ?? model.id]
        if let size = model.parameterSize { parts.append(size) }
        if let quant = model.quantization { parts.append(quant) }
        return parts.joined(separator: " · ")
    }
}
