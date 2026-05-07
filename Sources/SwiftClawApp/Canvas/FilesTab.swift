import SwiftUI
import SwiftClawCore

/// Canvas Files tab — workspace file tree. Clicking a file URL opens it in the Preview tab.
struct FilesTab: View {
    let sessionId: String
    let workspaceURL: URL?
    let onSelectFile: (String) -> Void

    @State private var entries: [FileEntry] = []

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Workspace is empty",
                    systemImage: "folder",
                    description: Text("Files written by the model will appear here.")
                )
            } else {
                List(entries) { entry in
                    HStack {
                        Image(systemName: entry.isDir ? "folder" : fileIcon(entry.name))
                            .foregroundStyle(entry.isDir ? .yellow : .secondary)
                        Text(entry.name)
                            .font(.system(.body, design: .monospaced))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !entry.isDir { onSelectFile(entry.relativePath) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear { reload() }
        .onChange(of: workspaceURL) { _, _ in reload() }
    }

    private func reload() {
        guard let base = workspaceURL else { entries = []; return }
        entries = collectEntries(url: base, prefix: "")
    }

    private func collectEntries(url: URL, prefix: String) -> [FileEntry] {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles
        ) else { return [] }

        var result: [FileEntry] = []
        for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = item.lastPathComponent
            guard !name.hasPrefix(".") && name != "node_modules" else { continue }
            let rel = prefix.isEmpty ? name : "\(prefix)/\(name)"
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            result.append(FileEntry(name: rel, relativePath: rel, isDir: isDir))
            if isDir {
                result.append(contentsOf: collectEntries(url: item, prefix: rel))
            }
        }
        return result
    }

    private func fileIcon(_ name: String) -> String {
        let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
        switch ext {
        case "html", "htm": return "globe"
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "curlybraces"
        case "css": return "paintbrush"
        case "json": return "doc.badge.gearshape"
        case "md": return "text.alignleft"
        case "png", "jpg", "jpeg", "svg", "gif", "webp": return "photo"
        default: return "doc"
        }
    }
}

private struct FileEntry: Identifiable {
    let id = UUID()
    let name: String
    let relativePath: String
    let isDir: Bool
}
