import SwiftUI
import SwiftClawUI

struct ChatDetailView: View {
    @Environment(ChatViewModel.self) private var viewModel
    @State private var isNearBottom = true

    var body: some View {
        @Bindable var vm = viewModel
        ZStack {
            // Dark dotted background
            DottedBackground()
                .ignoresSafeArea()

            // Light floating card
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        if viewModel.messages.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bird")
                                    .font(.system(size: 44))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Theme.brandBlue)
                                Text("ASK ANYTHING TO GET STARTED")
                                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(Theme.brandDeepBlue.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 120)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 14) {
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
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
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
                    .opacity(0.5)

                InputBarView(
                    text: $vm.inputText,
                    isGenerating: viewModel.isGenerating,
                    onSend: { viewModel.send() },
                    onStop: { viewModel.cancelGeneration() }
                )
            }
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color(red: 0.04, green: 0.12, blue: 0.18).opacity(0.45), radius: 32, x: 0, y: 8)
            .padding(16)
            .colorScheme(.light)

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
        .navigationTitle(viewModel.messages.isEmpty ? "SwiftClaw" : "Sysop")
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

// MARK: - Dotted background canvas

private struct DottedBackground: View {
    var body: some View {
        Theme.windowBackground
            .overlay(
                Canvas { context, size in
                    let spacing: CGFloat = 22
                    let dotRadius: CGFloat = 1.4
                    let color = Color.white.opacity(0.10)
                    var x: CGFloat = spacing
                    while x < size.width {
                        var y: CGFloat = spacing
                        while y < size.height {
                            let rect = CGRect(x: x - dotRadius, y: y - dotRadius,
                                             width: dotRadius * 2, height: dotRadius * 2)
                            context.fill(Path(ellipseIn: rect), with: .color(color))
                            y += spacing
                        }
                        x += spacing
                    }
                }
            )
    }
}
