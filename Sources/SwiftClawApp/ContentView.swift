import SwiftUI
import SwiftClawUI
import SwiftClawCore

struct ContentView: View {
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel
        NavigationSplitView {
            SessionListView(
                sessions: viewModel.sessions,
                selectedId: $vm.selectedSessionId,
                onDelete: { id in Task { await viewModel.deleteSession(id: id) } }
            )
            .onChange(of: viewModel.selectedSessionId) { _, newId in
                guard let id = newId else { return }
                Task { await viewModel.selectSession(id: id) }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.newChat() }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Start new chat")
                }
            }
        } detail: {
            if viewModel.selectedSessionId != nil || !viewModel.messages.isEmpty {
                ChatDetailView()
            } else {
                EmptyStateView(onNewChat: { Task { await viewModel.newChat() } })
                    .navigationTitle("SwiftClaw")
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            BackendStatusView(
                                backendType: viewModel.backendType,
                                modelId: viewModel.modelId,
                                state: viewModel.backendState
                            )
                        }
                    }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
