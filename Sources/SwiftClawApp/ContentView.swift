import SwiftClawCore
import SwiftClawUI
import SwiftUI

struct ContentView: View {
    @Environment(ChatViewModel.self) private var viewModel

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    @State private var sidebarSelection: NavSelection = .all
    @State private var metrics = SystemMetricsMonitor()

    var body: some View {
        @Bindable var vm = viewModel

        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarNavView(selection: $sidebarSelection)
                .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 280)
        } content: {
            SessionListColumn(folderFilter: folderFilter)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 420)
        } detail: {
            ChatDetailView()
                .toolbar {
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
        .navigationSplitViewStyle(.balanced)
        .onChange(of: viewModel.selectedSessionId) { _, newId in
            guard let id = newId else { return }
            Task { await viewModel.selectSession(id: id) }
        }
        .onChange(of: sidebarSelection) { _, new in
            viewModel.groupingMode = (new == .all) ? .time : .byFolder
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

    private var folderFilter: UUID? {
        if case let .folder(id) = sidebarSelection { return id }
        return nil
    }
}
