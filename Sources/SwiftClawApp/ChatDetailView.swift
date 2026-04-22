import SwiftClawUI
import SwiftUI

struct ChatDetailView: View {
    @Environment(ChatViewModel.self) private var viewModel
    @State private var isNearBottom = true
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        @Bindable var vm = viewModel
        ZStack(alignment: .bottomTrailing) {
            // Dark dotted background
            DottedBackground()
                .ignoresSafeArea()

            // Light floating card
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        if viewModel.messages.isEmpty {
                            VStack(spacing: 16) {
                                Spacer()

                                Image(systemName: "bird")
                                    .font(.system(size: 44))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Theme.brandBlue)

                                Text("WHAT CAN I HELP WITH?")
                                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(Theme.brandDeepBlue.opacity(0.5))

                                Spacer()

                                SuggestionChipsView(
                                    suggestions: [
                                        "What's my system info?",
                                        "Show disk usage",
                                        "List running processes",
                                        "What time is it?",
                                    ],
                                    onSelect: { viewModel.sendSuggestion($0) }
                                )
                                .padding(.horizontal, 32)
                                .padding(.bottom, 16)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                ChatTranscriptView(
                                    messages: viewModel.messages,
                                    onApproveToolCall: { callId in viewModel.approveToolCall(callId: callId) },
                                    onDenyToolCall: { callId in viewModel.denyToolCall(callId: callId) }
                                )
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
                    .onAppear { scrollProxy = proxy }
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
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .shadow(color: Theme.shadow, radius: 32, x: 0, y: 8)
            .padding(16)

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

            // Scroll-to-bottom pill — surfaces when the user scrolls up >100pt.
            if !isNearBottom, !viewModel.messages.isEmpty {
                SCButton(icon: "arrow.down", size: .small) {
                    withAnimation {
                        scrollProxy?.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .help("Scroll to latest")
                .padding(.trailing, 32)
                .padding(.bottom, 88)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isNearBottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                let usage = viewModel.contextUsage
                SCContextUsageIndicator(
                    used: usage.used,
                    total: usage.total,
                    isApproximate: usage.isApproximate
                )
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
                    let color = Theme.primaryForeground.opacity(0.04)
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
