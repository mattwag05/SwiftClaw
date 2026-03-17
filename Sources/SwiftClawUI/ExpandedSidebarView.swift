import SwiftUI
import SwiftClawCore

/// Expanded sidebar (~220pt) with time-grouped session rows.
public struct ExpandedSidebarView<SettingsContent: View>: View {
    public let groups: [SessionGroup]
    @Binding public var selectedId: String?
    public let onNewChat: () -> Void
    public let onToggleExpand: () -> Void
    public let onDelete: (String) -> Void
    @ViewBuilder public let settingsContent: () -> SettingsContent

    public init(
        groups: [SessionGroup],
        selectedId: Binding<String?>,
        onNewChat: @escaping () -> Void,
        onToggleExpand: @escaping () -> Void,
        onDelete: @escaping (String) -> Void,
        @ViewBuilder settingsContent: @escaping () -> SettingsContent
    ) {
        self.groups = groups
        self._selectedId = selectedId
        self.onNewChat = onNewChat
        self.onToggleExpand = onToggleExpand
        self.onDelete = onDelete
        self.settingsContent = settingsContent
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Button(action: onToggleExpand) {
                    Image(systemName: "bird")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.brandBlue)
                        .frame(width: 28, height: 28)
                        .background(Theme.brandBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)

                Text("Chats")
                    .font(.system(.headline, design: .default))
                    .foregroundStyle(Theme.sidebarLightText)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // New chat button
            Button(action: onNewChat) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12))
                    Text("New Chat")
                        .font(.system(.subheadline, design: .default).weight(.medium))
                }
                .foregroundStyle(Theme.brandBlue)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(Theme.brandBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.sidebarItemRadius))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // Divider
            Theme.sidebarDivider
                .frame(height: 1)
                .padding(.horizontal, 12)

            // Time-grouped session list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    ForEach(groups) { group in
                        // Section header
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(group.title.uppercased())
                                .font(.system(size: 9, design: .monospaced).weight(.medium))
                                .foregroundStyle(Theme.sidebarDimText)
                            Text("·")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.sidebarDimText)
                            Text(group.subtitle)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.sidebarDimText)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                        // Sessions in this group
                        ForEach(group.sessions) { summary in
                            sessionRow(summary)
                                .contextMenu {
                                    Button("Delete", role: .destructive) { onDelete(summary.sessionId) }
                                }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 0)

            // Settings slot
            Theme.sidebarDivider
                .frame(height: 1)
                .padding(.horizontal, 12)

            settingsContent()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: Theme.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(Theme.windowBackground)
    }

    @ViewBuilder
    private func sessionRow(_ summary: SessionSummary) -> some View {
        let isSelected = summary.sessionId == selectedId
        let preview = summary.preview.isEmpty ? "New chat" : summary.preview

        Button {
            selectedId = summary.sessionId
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(preview)
                    .lineLimit(1)
                    .font(.system(.subheadline))
                    .foregroundStyle(isSelected ? Theme.brandGold : Theme.sidebarLightText)
                Text(summary.updatedAt, style: .relative)
                    .font(Theme.monoFont)
                    .foregroundStyle(Theme.sidebarDimText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Theme.brandGold.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(isSelected ? Theme.brandGold.opacity(0.2) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preview)
    }
}
