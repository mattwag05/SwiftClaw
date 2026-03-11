import SwiftUI
import SwiftClawUI

struct ChatDetailView: View {
    @Environment(ChatViewModel.self) private var viewModel
    @State private var isNearBottom = true

    var body: some View {
        @Bindable var vm = viewModel
        ZStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.messages) { bubble in
                                ChatBubbleView(
                                    bubble: bubble,
                                    onApproveToolCall: { callId in viewModel.approveToolCall(callId: callId) },
                                    onDenyToolCall: { callId in viewModel.denyToolCall(callId: callId) }
                                )
                                .id(bubble.id)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding()
                    }
                    .onScrollGeometryChange(for: Bool.self) { geo in
                        let distanceFromBottom = geo.contentSize.height
                            - (geo.contentOffset.y + geo.visibleRect.height)
                        return distanceFromBottom < 100
                    } action: { _, nearBottom in
                        isNearBottom = nearBottom
                    }
                    .onChange(of: viewModel.messages.count) {
                        if isNearBottom {
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                    }
                    .onChange(of: viewModel.streamingContentVersion) {
                        if isNearBottom {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
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
