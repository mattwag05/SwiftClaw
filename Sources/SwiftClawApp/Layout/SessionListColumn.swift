import SwiftClawCore
import SwiftClawUI
import SwiftUI

/// Second column of the 3-column `NavigationSplitView`. Renders the grouped
/// session list with built-in search, right-click menu (rename / pin / move /
/// delete), and a "New Chat" toolbar button.
struct SessionListColumn: View {
    @Environment(ChatViewModel.self) private var viewModel

    /// Optional folder filter from the first column. `nil` shows everything.
    let folderFilter: UUID?

    @State private var renameTarget: SessionSummary?
    @State private var renameValue = ""
    @State private var deleteTarget: SessionSummary?

    var body: some View {
        @Bindable var vm = viewModel

        List(selection: $vm.selectedSessionId) {
            ForEach(visibleGroups) { group in
                Section(header: SessionGroupHeader(group: group)) {
                    ForEach(group.sessions) { summary in
                        SessionRowView(summary: summary)
                            .tag(Optional(summary.sessionId))
                            .contextMenu {
                                contextMenu(for: summary)
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $vm.sessionSearch, placement: .sidebar, prompt: "Search chats")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await vm.newChat() }
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(item: $renameTarget) { summary in
            RenameSessionSheet(value: $renameValue) {
                Task {
                    await vm.renameSession(id: summary.sessionId, to: renameValue)
                    renameTarget = nil
                }
            } onCancel: {
                renameTarget = nil
            }
        }
        .deleteConfirmationSheet(
            item: $deleteTarget,
            title: "Delete chat?",
            message: { summary in
                "“\(summary.displayTitle)” will be permanently removed. This cannot be undone."
            }
        ) { summary in
            Task { await vm.deleteSession(id: summary.sessionId) }
        }
    }

    // MARK: - Filtering & grouping

    private var visibleGroups: [SessionGroup] {
        guard let folderFilter else { return viewModel.groupedSessions }
        // Filter each group's sessions to just the folder, drop empties.
        return viewModel.groupedSessions.compactMap { group -> SessionGroup? in
            // Pinned sessions always show even if their folder differs.
            if group.id == "pinned" { return group }
            let filtered = group.sessions.filter { $0.folderID == folderFilter }
            guard !filtered.isEmpty else { return nil }
            return SessionGroup(id: group.id, title: group.title, sessions: filtered)
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenu(for summary: SessionSummary) -> some View {
        Button {
            renameTarget = summary
            renameValue = summary.title ?? summary.preview
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        if summary.isPinned {
            Button {
                Task { await viewModel.unpinSession(id: summary.sessionId) }
            } label: {
                Label("Unpin", systemImage: "pin.slash")
            }
        } else {
            Button {
                Task { await viewModel.pinSession(id: summary.sessionId) }
            } label: {
                Label("Pin", systemImage: "pin")
            }
        }

        if !viewModel.folders.isEmpty {
            Menu("Move to Folder") {
                Button("Unfiled") {
                    Task { await viewModel.moveSession(id: summary.sessionId, toFolder: nil) }
                }
                Divider()
                ForEach(viewModel.folders) { folder in
                    Button(folder.name) {
                        Task { await viewModel.moveSession(id: summary.sessionId, toFolder: folder.id) }
                    }
                }
            }
        }

        Divider()

        Button(role: .destructive) {
            deleteTarget = summary
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Group header

private struct SessionGroupHeader: View {
    let group: SessionGroup

    var body: some View {
        HStack {
            if group.id == "pinned" {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
            Text(group.title)
                .textStyle(.captionEmph)
                .foregroundStyle(Theme.foregroundSecondary)
            Spacer()
            Text("\(group.sessions.count)")
                .textStyle(.monoLabel)
                .foregroundStyle(Theme.foregroundTertiary)
        }
    }
}

// MARK: - Rename sheet

private struct RenameSessionSheet: View {
    @Binding var value: String
    let onRename: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Rename Chat")
                .textStyle(.heading)
            TextField("Title", text: $value)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onRename)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Rename", action: onRename)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 360)
    }
}
