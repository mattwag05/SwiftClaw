import SwiftUI
import SwiftClawCore

/// Collapsed icon-rail sidebar (52pt wide).
public struct SidebarRailView<SettingsContent: View>: View {
    public let sessions: [SessionSummary]
    @Binding public var selectedId: String?
    public let onNewChat: () -> Void
    public let onToggleExpand: () -> Void
    public let onDelete: (String) -> Void
    @ViewBuilder public let settingsContent: () -> SettingsContent

    public init(
        sessions: [SessionSummary],
        selectedId: Binding<String?>,
        onNewChat: @escaping () -> Void,
        onToggleExpand: @escaping () -> Void,
        onDelete: @escaping (String) -> Void,
        @ViewBuilder settingsContent: @escaping () -> SettingsContent
    ) {
        self.sessions = sessions
        self._selectedId = selectedId
        self.onNewChat = onNewChat
        self.onToggleExpand = onToggleExpand
        self.onDelete = onDelete
        self.settingsContent = settingsContent
    }

    public var body: some View {
        VStack(spacing: 4) {
            // Brand icon — toggles sidebar
            Button(action: onToggleExpand) {
                Image(systemName: "bird")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.brandBlue)
                    .frame(width: 32, height: 32)
                    .background(Theme.brandBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.sidebarItemRadius))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)

            // New chat
            Button(action: onNewChat) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.brandBlue)
                    .frame(width: 32, height: 32)
                    .background(Theme.brandBlue.opacity(0.15), in: RoundedRectangle(cornerRadius: Theme.sidebarItemRadius))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New chat")

            // Divider
            Theme.sidebarDivider
                .frame(width: 24, height: 1)
                .padding(.vertical, 4)

            // Session icons
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(sessions) { summary in
                        sessionIcon(summary)
                            .contextMenu {
                                Button("Delete", role: .destructive) { onDelete(summary.sessionId) }
                            }
                    }
                }
            }

            Spacer(minLength: 0)

            // Settings slot
            settingsContent()
                .padding(.bottom, 4)
        }
        .padding(.top, 12)
        .padding(.horizontal, 10)
        .frame(width: Theme.railWidth)
        .frame(maxHeight: .infinity)
        .background(Theme.windowBackground)
    }

    @ViewBuilder
    private func sessionIcon(_ summary: SessionSummary) -> some View {
        let isSelected = summary.sessionId == selectedId
        let initials = Self.initials(from: summary.preview)

        Button {
            selectedId = summary.sessionId
        } label: {
            Text(initials)
                .font(.system(size: 10, design: .monospaced).weight(.medium))
                .foregroundStyle(isSelected ? Theme.brandGold : Theme.sidebarLightText)
                .frame(width: 32, height: 32)
                .background(
                    isSelected ? Theme.brandGold.opacity(0.12) : Theme.sidebarItemBackground,
                    in: RoundedRectangle(cornerRadius: Theme.sidebarItemRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.sidebarItemRadius)
                        .strokeBorder(isSelected ? Theme.sidebarSelectedRing.opacity(0.5) : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(summary.preview.isEmpty ? "Chat session" : summary.preview)
    }

    static func initials(from preview: String) -> String {
        let words = preview.split(separator: " ").prefix(2)
        if words.isEmpty { return "SC" }
        if words.count == 1, let first = words.first?.first {
            return String(first).uppercased()
        }
        let result = words.compactMap(\.first).map { String($0).uppercased() }.joined()
        return result
    }
}
