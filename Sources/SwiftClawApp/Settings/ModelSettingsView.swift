import SwiftClawCore
import SwiftClawUI
import SwiftUI

struct ModelSettingsView: View {
    @Environment(ChatViewModel.self) private var viewModel
    @State private var showAdapters = false

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Model Card
                VStack(alignment: .leading, spacing: 10) {
                    let shortName = viewModel.modelId.components(separatedBy: "/").last ?? viewModel.modelId
                    Text(shortName)
                        .font(.headline)
                        .foregroundStyle(Theme.primaryForeground)

                    Text(viewModel.modelDescription)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryForeground)

                    HStack(spacing: 6) {
                        ForEach(viewModel.modelCapabilityBadges, id: \.self) { badge in
                            Text(badge)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.brandGold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.brandGold.opacity(0.12), in: Capsule())
                        }
                    }

                    if let ctx = viewModel.discoveredContextWindow {
                        Text("Detected context: \(ctx.formatted()) tokens")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.separatorColor, lineWidth: 1)
                )

                // Detected Models
                GroupBox("Detected Models") {
                    VStack(spacing: 0) {
                        if viewModel.isDiscoveringModels {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Scanning for models...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        } else if viewModel.availableModels.isEmpty {
                            HStack {
                                Text("No models detected.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Scan") {
                                    Task { await viewModel.discoverModels() }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                        } else {
                            ForEach(viewModel.availableModels) { model in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.id.components(separatedBy: "/").last ?? model.id)
                                            .font(.subheadline.weight(.medium))
                                        HStack(spacing: 6) {
                                            if let size = model.parameterSize {
                                                Text(size)
                                                    .font(.caption)
                                                    .foregroundStyle(Theme.brandGold)
                                            }
                                            if let quant = model.quantization {
                                                Text(quant)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let bytes = model.size {
                                                Text(ByteCountFormatter.string(
                                                    fromByteCount: bytes, countStyle: .file
                                                ))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                    if model.id == viewModel.modelId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.brandGold)
                                    } else {
                                        Button("Select") {
                                            Task { await viewModel.selectDiscoveredModel(model) }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                if model.id != viewModel.availableModels.last?.id {
                                    Divider().padding(.leading, 8)
                                }
                            }
                        }
                    }
                }

                GroupBox("Storage") {
                    VStack(spacing: 0) {
                        storageRow(label: "Device Memory", value: viewModel.totalRAM)
                        Divider().padding(.leading, 16)
                        storageRow(label: "Model Cache", value: viewModel.modelCacheSize)
                        Divider().padding(.leading, 16)
                        storageRow(label: "Available Storage", value: viewModel.availableStorage)
                    }
                }

                GroupBox("Generation") {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Temperature (\(String(format: "%.2f", viewModel.temperature)))")
                                .font(.subheadline)
                            Spacer()
                            Slider(value: $vm.temperature, in: 0 ... 2, step: 0.05)
                                .frame(width: 180)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        Divider()
                        Stepper("Max Tokens: \(viewModel.maxTokens)",
                                value: $vm.maxTokens, in: 256 ... 16384, step: 256)
                            .font(.subheadline)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                    }
                }

                GroupBox {
                    DisclosureGroup("Adapters", isExpanded: $showAdapters) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Auto-select best adapter", isOn: $vm.autoAdapter)
                                .font(.subheadline)

                            if !viewModel.autoAdapter {
                                Picker("Adapter", selection: $vm.selectedAdapter) {
                                    Text("None (base model)").tag(String?.none)
                                    ForEach(viewModel.adapters, id: \.name) { adapter in
                                        Text(adapter.name).tag(Optional(adapter.name))
                                    }
                                }
                                .font(.subheadline)
                            }

                            HStack {
                                Button("Refresh") { Task { await viewModel.refreshAdapters() } }
                                    .buttonStyle(.bordered)
                                if viewModel.adapters.isEmpty {
                                    Text("No adapters. Train with `swiftclaw train`.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .task {
            await viewModel.refreshStorageMetrics()
            await viewModel.discoverModels()
        }
    }

    private func storageRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.primaryForeground)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.secondaryForeground)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
    }
}
