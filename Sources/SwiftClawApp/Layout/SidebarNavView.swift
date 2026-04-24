import SwiftClawCore
import SwiftClawUI
import SwiftUI

/// First column of the 3-column `NavigationSplitView`. Shows the "All chats"
/// entry, user folders, and a bottom-anchored settings button. Drives the
/// session list's filter via `selection`.
///
/// `selection` semantics:
/// - `.all` shows the full session list grouped by time.
/// - `.folder(id)` filters the list to that folder (grouping switches to byFolder).
struct SidebarNavView: View {
    @Environment(ChatViewModel.self) private var viewModel

    @Binding var selection: NavSelection

    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var deleteTarget: Folder?

    var body: some View {
        @Bindable var vm = viewModel
        List(selection: $selection) {
            Section {
                Label("All Chats", systemImage: "tray.full")
                    .tag(NavSelection.all)
            }

            Section("Folders") {
                ForEach(vm.folders) { folder in
                    Label(folder.name, systemImage: "folder")
                        .tag(NavSelection.folder(folder.id))
                        .contextMenu {
                            Button("Rename") {
                                renameTarget = folder
                                renameValue = folder.name
                            }
                            Button("Delete", role: .destructive) {
                                deleteTarget = folder
                            }
                        }
                }
                Button {
                    showNewFolder = true
                } label: {
                    Label("New Folder…", systemImage: "plus")
                        .foregroundStyle(Theme.foregroundSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            SettingsFooter()
        }
        .sheet(isPresented: $showNewFolder) {
            NewFolderSheet(name: $newFolderName) {
                Task {
                    await vm.createFolder(name: newFolderName)
                    newFolderName = ""
                    showNewFolder = false
                }
            } onCancel: {
                newFolderName = ""
                showNewFolder = false
            }
        }
        .sheet(item: $renameTarget) { folder in
            RenameFolderSheet(value: $renameValue) {
                Task {
                    await vm.renameFolder(id: folder.id, to: renameValue)
                    renameTarget = nil
                }
            } onCancel: {
                renameTarget = nil
            }
        }
        .deleteConfirmationSheet(
            item: $deleteTarget,
            title: "Delete folder?",
            message: { folder in
                let childCount = viewModel.sessions.count(where: { $0.folderID == folder.id })
                switch childCount {
                case 0: return "“\(folder.name)” will be removed. No chats will be deleted."
                case 1: return "“\(folder.name)” will be removed and its 1 chat moved to Unfiled."
                default: return "“\(folder.name)” will be removed and its \(childCount) chats moved to Unfiled."
                }
            }
        ) { folder in
            Task { await vm.deleteFolder(id: folder.id) }
        }
    }

    @State private var renameTarget: Folder?
    @State private var renameValue = ""
}

/// Which node of the sidebar is selected. Drives the session list's filter
/// predicate.
enum NavSelection: Hashable {
    case all
    case folder(UUID)
}

// MARK: - Bottom settings footer

private struct SettingsFooter: View {
    @State private var showPopover = false
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        HStack {
            Button {
                showPopover.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.foregroundSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .popover(
                isPresented: $showPopover,
                attachmentAnchor: .point(.trailing),
                arrowEdge: .trailing
            ) {
                QuickSettingsPopover()
                    .environment(viewModel)
            }
            .accessibilityLabel("Settings")
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
    }
}

// MARK: - New / rename folder sheets

private struct NewFolderSheet: View {
    @Binding var name: String
    let onCreate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("New Folder")
                .textStyle(.heading)
            TextField("Folder name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onCreate)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Create", action: onCreate)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 320)
    }
}

private struct RenameFolderSheet: View {
    @Binding var value: String
    let onRename: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Rename Folder")
                .textStyle(.heading)
            TextField("New name", text: $value)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onRename)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Rename", action: onRename)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(value.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 320)
    }
}
