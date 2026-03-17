import SwiftUI
import SwiftClawUI
import SwiftClawCore

struct ContentView: View {
    @Environment(ChatViewModel.self) private var viewModel
    @AppStorage("sidebarExpanded") private var sidebarExpanded = false
    @State private var showQuickSettings = false
    @State private var metrics = SystemMetricsMonitor()

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            HStack(spacing: 0) {
                // Sidebar (rail or expanded)
                if sidebarExpanded {
                    ExpandedSidebarView(
                        groups: viewModel.groupedSessions,
                        selectedId: $vm.selectedSessionId,
                        onNewChat: { Task { await viewModel.newChat() } },
                        onToggleExpand: { withAnimation(.easeInOut(duration: 0.2)) { sidebarExpanded.toggle() } },
                        onDelete: { id in Task { await viewModel.deleteSession(id: id) } },
                        settingsContent: { settingsButton }
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    SidebarRailView(
                        sessions: viewModel.sessions,
                        selectedId: $vm.selectedSessionId,
                        onNewChat: { Task { await viewModel.newChat() } },
                        onToggleExpand: { withAnimation(.easeInOut(duration: 0.2)) { sidebarExpanded.toggle() } },
                        onDelete: { id in Task { await viewModel.deleteSession(id: id) } },
                        settingsContent: { settingsButton }
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                // Chat area — always visible
                ChatDetailView()
            }
            .onChange(of: viewModel.selectedSessionId) { _, newId in
                guard let id = newId else { return }
                Task { await viewModel.selectSession(id: id) }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { sidebarExpanded.toggle() }
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .accessibilityLabel("Toggle sidebar")
                }

                ToolbarItem(placement: .automatic) {
                    BackendStatusView(
                        backendType: viewModel.backendType,
                        modelId: viewModel.modelId,
                        state: viewModel.backendState,
                        ramUsage: metrics.formattedRAM,
                        cpuUsage: metrics.formattedCPU
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
            .navigationTitle("SwiftClaw")
        }
        .onAppear { metrics.start() }
        .onDisappear { metrics.stop() }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        Button { showQuickSettings.toggle() } label: {
            Image(systemName: "gear")
                .font(.system(size: 14))
                .foregroundStyle(Theme.sidebarDimText)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showQuickSettings, arrowEdge: .trailing) {
            QuickSettingsPopover()
                .environment(viewModel)
        }
        .accessibilityLabel("Settings")
    }
}
