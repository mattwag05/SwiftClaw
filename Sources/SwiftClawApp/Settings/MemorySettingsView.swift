import SwiftClawUI
import SwiftUI

struct MemorySettingsView: View {
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
