import AppKit
import SwiftClawCore
import SwiftClawUI
import SwiftUI

/// Top-level container view for the Perplexity-style SwiftClaw window.
///
/// Replaces the legacy 3-column `NavigationSplitView` with a Perplexity-style
/// 2-column layout: a fixed-width sidebar on the left and the chat pane
/// taking the remaining width. The sidebar can be hidden via ⌘\.
struct PerplexityRoot: View {
    @Environment(ChatViewModel.self) private var viewModel
    @Environment(CommandRegistry.self) private var commandRegistry

    @State private var navSelection: NavSelection = .all
    @State private var sidebarVisible: Bool = true

    var body: some View {
        @Bindable var vm = viewModel

        HStack(spacing: 0) {
            if sidebarVisible {
                PerplexitySidebar(
                    navSelection: $navSelection,
                    onOpenSettings: openSettings
                )
                .frame(width: PXTheme.Layout.sidebarWidth)
                .transition(.move(edge: .leading).combined(with: .opacity))
                Divider()
                    .opacity(0.4)
            }
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    if !sidebarVisible {
                        // Push the reveal button right of the traffic-light cluster
                        // so it doesn't sit on top of close/minimize/zoom.
                        revealSidebarButton
                            .padding(.top, 14)
                            .padding(.leading, 84)
                    }
                }
        }
        .background(PXTheme.windowBg)
        .onChange(of: viewModel.selectedSessionId) { _, newId in
            guard let id = newId else { return }
            Task { await viewModel.selectSession(id: id) }
        }
        .onChange(of: navSelection) { _, new in
            switch new {
            case .all, .spaces, .artifacts, .customize: viewModel.groupingMode = .time
            case .folder: viewModel.groupingMode = .byFolder
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
        .onReceive(NotificationCenter.default.publisher(for: .pxToggleSidebar)) { _ in
            withAnimation(PXTheme.Motion.snap) { sidebarVisible.toggle() }
        }
        .sheet(isPresented: Binding(
            get: { commandRegistry.isPresented },
            set: { commandRegistry.isPresented = $0 }
        )) {
            CommandPaletteView(
                onOpenSettings: openSettings,
                onToggleSidebar: {
                    withAnimation(PXTheme.Motion.snap) { sidebarVisible.toggle() }
                }
            )
        }
    }

    private var revealSidebarButton: some View {
        Button {
            withAnimation(PXTheme.Motion.snap) { sidebarVisible.toggle() }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PXTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(PXTheme.surface1.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(PXTheme.borderHairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help("Show sidebar (⌘\\)")
    }

    @ViewBuilder
    private var mainContent: some View {
        switch navSelection {
        case .all, .folder:
            PerplexityChatPane()
        case .spaces:
            SpacesPane(navSelection: $navSelection)
        case .artifacts:
            ArtifactsPane()
        case .customize:
            CustomizePane()
        }
    }

    private func openSettings() {
        // SwiftUI Settings scene action — works on macOS 14+.
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
