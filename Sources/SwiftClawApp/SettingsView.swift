import SwiftClawUI
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }
            ModelSettingsTab()
                .tabItem { Label("Model", systemImage: "slider.horizontal.3") }
            ToolsMemorySettingsTab()
                .tabItem { Label("Tools & Memory", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 540, height: 480)
        .padding()
    }
}

// MARK: - General

struct GeneralSettingsTab: View {
    @Environment(ChatViewModel.self) private var viewModel
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

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

// MARK: - Model

struct ModelSettingsTab: View {
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
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.separatorColor, lineWidth: 1)
                )

                // Storage
                GroupBox("Storage") {
                    VStack(spacing: 0) {
                        storageRow(label: "Device Memory", value: viewModel.totalRAM)
                        Divider().padding(.leading, 16)
                        storageRow(label: "Model Cache", value: viewModel.modelCacheSize)
                        Divider().padding(.leading, 16)
                        storageRow(label: "Available Storage", value: viewModel.availableStorage)
                    }
                }

                // Generation
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

                // Adapters (collapsible)
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
        .task { await viewModel.refreshStorageMetrics() }
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

// MARK: - Tools & Memory

struct ToolsMemorySettingsTab: View {
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            Section("Memory") {
                Toggle("Enable agent memory", isOn: $vm.memoryEnabled)

                if viewModel.memoryEnabled {
                    Text("Memory database: ~/.swiftclaw/memory/memories.db")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    embeddingStateView

                    Button("Re-index Embeddings") {
                        Task { await viewModel.reindexMemory() }
                    }
                    .help("Clears stored embedding vectors and re-embeds all memories.")
                }
            }

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

    @ViewBuilder
    private var embeddingStateView: some View {
        switch viewModel.embeddingState {
        case .idle:
            Text("MLX embeddings will load on first memory write")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .loading(pct):
            HStack {
                ProgressView().scaleEffect(0.7)
                Text("Loading nomic-embed model (\(Int(pct * 100))%)…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .ready:
            Label("MLX embeddings ready", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .unavailable:
            Label("Using hash-based fallback", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
