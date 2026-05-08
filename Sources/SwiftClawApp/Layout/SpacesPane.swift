import SwiftClawCore
import SwiftClawUI
import SwiftUI

/// Spaces grid — folders rendered as cards. Clicking a card filters the
/// sidebar to that folder and shows the chat pane for the most recent thread
/// in it.
struct SpacesPane: View {
    @Environment(ChatViewModel.self) private var viewModel
    @Binding var navSelection: NavSelection
    @State private var newSpaceName: String = ""
    @State private var creatingSpace: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if viewModel.folders.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .background(PXTheme.chatBg)
        .sheet(isPresented: $creatingSpace) {
            VStack(alignment: .leading, spacing: 14) {
                Text("New Space")
                    .font(.system(size: 15, weight: .semibold))
                TextField("Space name", text: $newSpaceName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(create)
                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) {
                        newSpaceName = ""
                        creatingSpace = false
                    }
                    Button("Create", action: create)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(newSpaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 320)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spaces")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(PXTheme.textPrimary)
                Text("Group related threads. Pin reference docs and prompts to a space.")
                    .font(.system(size: 13))
                    .foregroundStyle(PXTheme.textSecondary)
            }
            Spacer()
            Button {
                creatingSpace = true
            } label: {
                Label("New Space", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(PXTheme.accent)
                    )
                    .foregroundStyle(PXTheme.onAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(PXTheme.textTertiary)
            Text("No spaces yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PXTheme.textSecondary)
            Text("Create a space to group threads — perfect for projects, courses, or topics.")
                .font(.system(size: 12))
                .foregroundStyle(PXTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 80)
            Button {
                creatingSpace = true
            } label: {
                Text("Create your first space")
                    .font(.system(size: 12.5, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(PXTheme.surface2)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)],
                spacing: 14
            ) {
                ForEach(viewModel.folders) { folder in
                    spaceCard(folder)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    private func spaceCard(_ folder: Folder) -> some View {
        let count = viewModel.sessions.count(where: { $0.folderID == folder.id })
        return Button {
            navSelection = .folder(folder.id)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 14))
                        .foregroundStyle(PXTheme.accent)
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PXTheme.textTertiary)
                }
                Text(folder.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PXTheme.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(count == 1 ? "1 thread" : "\(count) threads")")
                    .font(.system(size: 11))
                    .foregroundStyle(PXTheme.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 110)
            .background(PXTheme.surface1)
            .clipShape(RoundedRectangle(cornerRadius: PXTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PXTheme.Radius.card, style: .continuous)
                    .strokeBorder(PXTheme.borderHairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open") { navSelection = .folder(folder.id) }
            Divider()
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteFolder(id: folder.id) }
            }
        }
    }

    private func create() {
        let trimmed = newSpaceName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task {
            await viewModel.createFolder(name: trimmed)
            newSpaceName = ""
            creatingSpace = false
        }
    }
}
