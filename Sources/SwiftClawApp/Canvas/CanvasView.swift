import SwiftUI
import SwiftClawCore

/// The Canvas pane shown to the right of the chat when a Build-mode session is active.
///
/// Three tabs: Preview (WKWebView), Code (live write stream), Files (workspace tree).
/// The tab header also shows a status pill and close button.
struct CanvasView: View {
    let sessionId: String
    let workspaceManager: WorkspaceManager

    @Environment(ChatViewModel.self) private var viewModel

    @State private var selectedTab: CanvasTab = .preview
    @State private var previewFilePath: String? = nil

    enum CanvasTab: String, CaseIterable {
        case preview = "Preview"
        case code = "Code"
        case files = "Files"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                // Tab picker
                HStack(spacing: 0) {
                    ForEach(CanvasTab.allCases, id: \.rawValue) { tab in
                        Button(tab.rawValue) {
                            selectedTab = tab
                        }
                        .buttonStyle(.plain)
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedTab == tab
                                ? Color.primary.opacity(0.08)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                    }
                }

                Spacer()

                // Status pill
                if viewModel.currentlyWritingFile != nil {
                    Label("Writing", systemImage: "pencil")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.1), in: Capsule())
                }

                // Refresh button
                Button {
                    previewFilePath = UUID().uuidString   // force reload
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)

                // Open in Finder
                Button {
                    Task {
                        let url = await workspaceManager.path(for: sessionId)
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)

                // Close
                Button {
                    viewModel.canvasOpen = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
                .padding(.trailing, 8)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(.bar)

            Divider()

            // Content
            switch selectedTab {
            case .preview:
                PreviewTab(
                    sessionId: sessionId,
                    workspaceManager: workspaceManager,
                    lastWrittenPath: viewModel.canvasFileWrittenPath
                )

            case .code:
                CodeTab(writingFile: viewModel.currentlyWritingFile)

            case .files:
                FilesTabWrapper(
                    sessionId: sessionId,
                    workspaceManager: workspaceManager,
                    onSelectFile: { path in
                        previewFilePath = path
                        selectedTab = .preview
                    }
                )
            }
        }
        .onChange(of: viewModel.currentlyWritingFile?.path) { _, newPath in
            if newPath != nil { selectedTab = .code }
        }
        .onChange(of: viewModel.canvasFileWrittenPath) { _, _ in
            // Auto-switch to Preview 1.4s after file is done writing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                if viewModel.currentlyWritingFile == nil {
                    selectedTab = .preview
                }
            }
        }
    }
}

/// Wrapper that resolves workspace URL async.
private struct FilesTabWrapper: View {
    let sessionId: String
    let workspaceManager: WorkspaceManager
    let onSelectFile: (String) -> Void

    @State private var workspaceURL: URL? = nil

    var body: some View {
        FilesTab(
            sessionId: sessionId,
            workspaceURL: workspaceURL,
            onSelectFile: onSelectFile
        )
        .task {
            workspaceURL = await workspaceManager.path(for: sessionId)
        }
    }
}
