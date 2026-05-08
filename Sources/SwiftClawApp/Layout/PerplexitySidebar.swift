import AppKit
import SwiftClawCore
import SwiftClawUI
import SwiftUI

/// Single-column sidebar inspired by Perplexity Computer.
///
/// Layout (top → bottom):
///   • Window controls inset
///   • "+ New Thread" prominent button
///   • Sections (All Chats / Folders / Spaces)
///   • Search
///   • Recent (grouped by Today / Yesterday / older)
///   • Settings footer
struct PerplexitySidebar: View {
    @Environment(ChatViewModel.self) private var viewModel
    @Binding var navSelection: NavSelection
    let onOpenSettings: () -> Void

    @State private var newFolderTarget: Bool = false
    @State private var newFolderName: String = ""
    @State private var renameTarget: SessionSummary?
    @State private var renameValue: String = ""
    @State private var deleteTarget: SessionSummary?
    @State private var folderDeleteTarget: Folder?
    @State private var folderRenameTarget: Folder?
    @State private var folderRenameValue: String = ""

    var body: some View {
        @Bindable var vm = viewModel
        VStack(alignment: .leading, spacing: 0) {
            // Reserve room for the inset traffic lights
            Spacer().frame(height: 32)

            // New Thread button
            Button {
                Task { await viewModel.newChat() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13, weight: .semibold))
                    Text("New Thread")
                        .font(.system(size: 13.5, weight: .semibold))
                    Spacer()
                    Text("⌘N")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(PXTheme.textTertiary)
                }
                .foregroundStyle(PXTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PXTheme.Radius.button, style: .continuous)
                        .fill(PXTheme.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PXTheme.Radius.button, style: .continuous)
                        .strokeBorder(PXTheme.borderHairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            // Nav links
            VStack(alignment: .leading, spacing: 2) {
                navItem(title: "All Threads", systemImage: "tray.full", selection: .all)
                navItem(title: "Spaces", systemImage: "rectangle.3.group", selection: .spaces)
                navItem(title: "Artifacts", systemImage: "sparkles.rectangle.stack", selection: .artifacts)
                navItem(title: "Customize", systemImage: "slider.horizontal.3", selection: .customize)
            }
            .padding(.horizontal, 8)
            .padding(.top, 14)

            // Folders / Spaces section
            if !viewModel.folders.isEmpty {
                sectionHeader("Spaces")
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(viewModel.folders) { folder in
                        navItem(
                            title: folder.name,
                            systemImage: "folder",
                            selection: .folder(folder.id)
                        )
                        .contextMenu {
                            Button("Rename") {
                                folderRenameTarget = folder
                                folderRenameValue = folder.name
                            }
                            Button("Delete", role: .destructive) {
                                folderDeleteTarget = folder
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            // Add space
            Button {
                newFolderTarget = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("New Space")
                        .font(.system(size: 12.5))
                }
                .foregroundStyle(PXTheme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.top, 2)

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(PXTheme.textTertiary)
                TextField("Search threads", text: $vm.sessionSearch)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(PXTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PXTheme.surface1.opacity(0.6))
            )
            .padding(.horizontal, 12)
            .padding(.top, 16)

            // Recent threads list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 1, pinnedViews: [.sectionHeaders]) {
                    if visibleGroups.allSatisfy({ $0.sessions.isEmpty }) {
                        emptyRecent
                    } else {
                        ForEach(visibleGroups) { group in
                            Section(header: groupHeader(group)) {
                                ForEach(group.sessions) { summary in
                                    sessionRow(summary)
                                        .contextMenu { sessionContextMenu(summary) }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Footer
            Divider().opacity(0.5)
            HStack(spacing: 6) {
                Button(action: onOpenSettings) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                        Text("Settings")
                            .font(.system(size: 12.5))
                    }
                    .foregroundStyle(PXTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(footerLabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(PXTheme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.trailing, 10)
                    .help(viewModel.modelId)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .background(PXTheme.sidebarBg)
        .frame(minWidth: PXTheme.Layout.sidebarWidth, idealWidth: PXTheme.Layout.sidebarWidth, maxWidth: 320)
        .sheet(isPresented: $newFolderTarget) {
            simpleSheet(
                title: "New Space",
                value: $newFolderName,
                placeholder: "Space name",
                action: "Create"
            ) {
                Task {
                    await viewModel.createFolder(name: newFolderName)
                    newFolderName = ""
                    newFolderTarget = false
                }
            } onCancel: {
                newFolderName = ""
                newFolderTarget = false
            }
        }
        .sheet(item: $renameTarget) { summary in
            simpleSheet(
                title: "Rename Thread",
                value: $renameValue,
                placeholder: "Thread title",
                action: "Rename"
            ) {
                Task {
                    await viewModel.renameSession(id: summary.sessionId, to: renameValue)
                    renameTarget = nil
                }
            } onCancel: {
                renameTarget = nil
            }
        }
        .sheet(item: $folderRenameTarget) { folder in
            simpleSheet(
                title: "Rename Space",
                value: $folderRenameValue,
                placeholder: "Space name",
                action: "Rename"
            ) {
                Task {
                    await viewModel.renameFolder(id: folder.id, to: folderRenameValue)
                    folderRenameTarget = nil
                }
            } onCancel: {
                folderRenameTarget = nil
            }
        }
        .alert(item: $deleteTarget) { summary in
            Alert(
                title: Text("Delete thread?"),
                message: Text("“\(summary.displayTitle)” will be permanently removed."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await viewModel.deleteSession(id: summary.sessionId) }
                },
                secondaryButton: .cancel()
            )
        }
        .alert(item: $folderDeleteTarget) { folder in
            Alert(
                title: Text("Delete space?"),
                message: Text("“\(folder.name)” will be removed. Threads inside move to Unfiled."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await viewModel.deleteFolder(id: folder.id) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Subviews

    private func navItem(
        title: String,
        systemImage: String,
        selection: NavSelection
    ) -> some View {
        NavRow(
            title: title,
            systemImage: systemImage,
            active: navSelection == selection
        ) {
            navSelection = selection
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .default))
            .tracking(0.6)
            .foregroundStyle(PXTheme.textTertiary)
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }

    private var emptyRecent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RECENT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(PXTheme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 4)
            Text("No threads yet. Press ⌘N to start one.")
                .font(.system(size: 11))
                .foregroundStyle(PXTheme.textTertiary.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.top, 2)
        }
    }

    private func groupHeader(_ group: SessionGroup) -> some View {
        HStack {
            Text(group.title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(PXTheme.textTertiary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .background(PXTheme.sidebarBg)
    }

    private func sessionRow(_ summary: SessionSummary) -> some View {
        SessionRow(
            summary: summary,
            active: viewModel.selectedSessionId == summary.sessionId
        ) {
            viewModel.selectedSessionId = summary.sessionId
        }
    }

    @ViewBuilder
    private func sessionContextMenu(_ summary: SessionSummary) -> some View {
        Button("Rename") {
            renameTarget = summary
            renameValue = summary.title ?? summary.preview
        }
        if summary.isPinned {
            Button("Unpin") {
                Task { await viewModel.unpinSession(id: summary.sessionId) }
            }
        } else {
            Button("Pin") {
                Task { await viewModel.pinSession(id: summary.sessionId) }
            }
        }
        if !viewModel.folders.isEmpty {
            Menu("Move to Space") {
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
        Button("Delete", role: .destructive) {
            deleteTarget = summary
        }
    }

    private var footerLabel: String {
        let backend = viewModel.backendType == .mlx ? "MLX" : "Ollama"
        let short = viewModel.modelId.components(separatedBy: "/").last ?? viewModel.modelId
        return "\(backend) · \(short)"
    }

    private var visibleGroups: [SessionGroup] {
        let groups = viewModel.groupedSessions
        switch navSelection {
        case .all, .spaces, .artifacts, .customize:
            return groups
        case let .folder(id):
            return groups.compactMap { g -> SessionGroup? in
                if g.id == "pinned" { return g }
                let filtered = g.sessions.filter { $0.folderID == id }
                guard !filtered.isEmpty else { return nil }
                return SessionGroup(id: g.id, title: g.title, sessions: filtered)
            }
        }
    }

    private func simpleSheet(
        title: String,
        value: Binding<String>,
        placeholder: String,
        action: String,
        onSubmit: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            TextField(placeholder, text: value)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onSubmit)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button(action, action: onSubmit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(value.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

// MARK: - NavSelection (shared)

/// Sidebar selection. Extended from the legacy `NavSelection` to add `.spaces`.
enum NavSelection: Hashable {
    case all
    case spaces
    case artifacts
    case customize
    case folder(UUID)
}
