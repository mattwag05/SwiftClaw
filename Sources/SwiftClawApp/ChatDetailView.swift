import SwiftClawCore
import SwiftClawUI
import SwiftUI

struct ChatDetailView: View {
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        if viewModel.sessionMode == .build && viewModel.canvasOpen,
           let sessionId = viewModel.selectedSessionId {
            HSplitView {
                chatBody()
                    .frame(minWidth: 340)
                CanvasView(
                    sessionId: sessionId,
                    workspaceManager: viewModel.workspaceManager
                )
                .frame(minWidth: 320)
            }
        } else {
            chatBody()
        }
    }

    @ViewBuilder
    private func chatBody() -> some View {
        @Bindable var vm = viewModel
        VStack(spacing: 0) {
            // Header bar: title + mode picker + canvas toggle
            GemmaHeaderBar(
                title: viewModel.sessions.first(where: { $0.sessionId == viewModel.selectedSessionId })?.displayTitle,
                mode: $vm.sessionMode,
                canvasOpen: $vm.canvasOpen,
                hasSession: viewModel.selectedSessionId != nil
            )

            Divider()
                .opacity(0.5)

            // Message area
            if viewModel.messages.isEmpty {
                GemmaEmptyState(mode: viewModel.sessionMode) { suggestion in
                    viewModel.sendSuggestion(suggestion)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GemmaMessageList(
                    messages: viewModel.messages,
                    onApproveToolCall: { callId in viewModel.approveToolCall(callId: callId) },
                    onDenyToolCall: { callId in viewModel.denyToolCall(callId: callId) },
                    onCopyBubble: { bubble in viewModel.copyBubble(bubble) },
                    onRegenerateBubble: { _ in viewModel.regenerate() }
                )
            }

            Divider()
                .opacity(0.5)

            // Composer
            GemmaComposer(
                text: $vm.inputText,
                isGenerating: viewModel.isGenerating,
                onSend: { viewModel.send() },
                onStop: { viewModel.cancelGeneration() }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(GemmaBackground.fill)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Backend overlays
        .overlay(alignment: .center) {
            if case let .loading(progress) = viewModel.backendState {
                ModelLoadingOverlay(progress: progress)
            }
        }
        .overlay(alignment: .top) {
            if case let .error(msg) = viewModel.backendState {
                ErrorBannerView(message: msg) {
                    Task { await viewModel.loadBackend() }
                }
            }
        }
    }
}
