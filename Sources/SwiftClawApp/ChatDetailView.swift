import SwiftUI
import SwiftClawUI

struct ChatDetailView: View {
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel
        ZStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.messages) { bubble in
                                ChatBubbleView(bubble: bubble)
                                    .id(bubble.id)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }

                Divider()

                InputBarView(
                    text: $vm.inputText,
                    isGenerating: viewModel.isGenerating,
                    onSend: { viewModel.send() },
                    onStop: { viewModel.cancelGeneration() }
                )
            }

            // Backend loading overlay
            if case let .loading(progress) = viewModel.backendState {
                ModelLoadingOverlay(progress: progress)
            }

            // Backend error banner
            if case let .error(msg) = viewModel.backendState {
                ErrorBannerView(message: msg) {
                    Task { await viewModel.loadBackend() }
                }
            }
        }
        .navigationTitle(viewModel.selectedSessionId.map { _ in "Sysop" } ?? "SwiftClaw")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                BackendStatusView(
                    backendType: viewModel.backendType,
                    modelId: viewModel.modelId,
                    state: viewModel.backendState
                )
            }
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isGenerating {
                    Button {
                        viewModel.cancelGeneration()
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("Stop generating")
                }
            }
        }
    }
}
