import SwiftClawCore
import SwiftClawUI
import SwiftUI

/// "Artifacts" view — placeholder grid of files generated across builds.
///
/// Today this scans every session's workspace under `~/Library/Application
/// Support/SwiftClaw/workspaces/<sessionId>/` and presents the most recently
/// touched files. Clicking an item opens it in the Canvas Preview tab.
struct ArtifactsPane: View {
    @Environment(ChatViewModel.self) private var viewModel
    @State private var artifacts: [ArtifactItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if artifacts.isEmpty {
                emptyState
            } else {
                artifactGrid
            }
        }
        .background(PXTheme.chatBg)
        .task { await refresh() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Artifacts")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(PXTheme.textPrimary)
                Text("Files SwiftClaw built across your threads.")
                    .font(.system(size: 13))
                    .foregroundStyle(PXTheme.textSecondary)
            }
            Spacer()
            Button {
                Task { await refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PXTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(PXTheme.surface1)
                    )
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(PXTheme.textTertiary)
            Text("No artifacts yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PXTheme.textSecondary)
            Text("Files SwiftClaw writes during a Build session show up here.")
                .font(.system(size: 12))
                .foregroundStyle(PXTheme.textTertiary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var artifactGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 14)],
                spacing: 14
            ) {
                ForEach(artifacts) { item in
                    artifactCard(item)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    private func artifactCard(_ item: ArtifactItem) -> some View {
        Button {
            NSWorkspace.shared.open(item.url)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: item.iconName)
                        .font(.system(size: 14))
                        .foregroundStyle(PXTheme.accent)
                    Text(item.url.lastPathComponent)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                Text(item.relativePath)
                    .font(.system(size: 11))
                    .foregroundStyle(PXTheme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack {
                    Text(item.modifiedAgo)
                        .font(.system(size: 10.5, design: .monospaced))
                    Spacer()
                    Text(item.sizeText)
                        .font(.system(size: 10.5, design: .monospaced))
                }
                .foregroundStyle(PXTheme.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PXTheme.surface1)
            .clipShape(RoundedRectangle(cornerRadius: PXTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PXTheme.Radius.card, style: .continuous)
                    .strokeBorder(PXTheme.borderHairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading

    private func refresh() async {
        let url = WorkspaceManager.defaultBaseDir
        let scanned = await Task.detached(priority: .userInitiated) {
            ArtifactScanner.scan(under: url)
        }.value
        artifacts = scanned
    }
}

// MARK: - Artifact model + scanner

struct ArtifactItem: Identifiable {
    let id: String
    let url: URL
    let relativePath: String
    let modifiedAt: Date
    let sizeBytes: Int64

    var iconName: String {
        switch url.pathExtension.lowercased() {
        case "swift": return "swift"
        case "py": return "scroll"
        case "js", "ts", "tsx", "jsx": return "curlybraces"
        case "html", "css": return "globe"
        case "md": return "doc.text"
        case "png", "jpg", "jpeg", "gif": return "photo"
        default: return "doc"
        }
    }

    var modifiedAgo: String {
        let interval = Date().timeIntervalSince(modifiedAt)
        switch interval {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(interval / 60))m ago"
        case ..<86400: return "\(Int(interval / 3600))h ago"
        default: return "\(Int(interval / 86400))d ago"
        }
    }

    var sizeText: String {
        let kb = Double(sizeBytes) / 1024.0
        if kb < 1 { return "\(sizeBytes) B" }
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        return String(format: "%.1f MB", kb / 1024)
    }
}

enum ArtifactScanner {
    static func scan(under root: URL) -> [ArtifactItem] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var found: [ArtifactItem] = []
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [
                .isRegularFileKey,
                .contentModificationDateKey,
                .fileSizeKey,
            ])
            guard values?.isRegularFile == true else { continue }
            let rel = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
            found.append(ArtifactItem(
                id: fileURL.path,
                url: fileURL,
                relativePath: rel,
                modifiedAt: values?.contentModificationDate ?? Date.distantPast,
                sizeBytes: Int64(values?.fileSize ?? 0)
            ))
            if found.count > 200 { break }
        }
        return found.sorted(by: { $0.modifiedAt > $1.modifiedAt }).prefix(120).map { $0 }
    }
}
