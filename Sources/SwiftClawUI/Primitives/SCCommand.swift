import SwiftUI

/// Command-palette inner view.
///
/// Host this inside a sheet, popover, or floating panel — `SCCommand` does
/// not present itself. It provides an auto-focused search field, a filtered
/// list of items (substring match on title + subtitle), keyboard navigation
/// via arrow keys, Enter to run, and Escape to dismiss.
public struct SCCommand: View {
    public struct Item: Identifiable {
        public let id: String
        public let title: String
        public let subtitle: String?
        public let icon: String?
        public let shortcut: String?
        public let action: () -> Void

        public init(
            id: String,
            title: String,
            subtitle: String? = nil,
            icon: String? = nil,
            shortcut: String? = nil,
            action: @escaping () -> Void
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.shortcut = shortcut
            self.action = action
        }
    }

    private let placeholder: String
    private let items: [Item]
    private let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFocused: Bool

    public init(
        placeholder: String = "Type a command…",
        items: [Item],
        onDismiss: @escaping () -> Void
    ) {
        self.placeholder = placeholder
        self.items = items
        self.onDismiss = onDismiss
    }

    private var filtered: [Item] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { item in
            if item.title.lowercased().contains(q) { return true }
            if let sub = item.subtitle?.lowercased(), sub.contains(q) { return true }
            return false
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
                .padding(Spacing.sm)

            Rectangle()
                .fill(Theme.borderSubtle)
                .frame(height: 1)

            list
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Theme.surfaceRaised)
        )
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
        .onAppear {
            searchFocused = true
        }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.foregroundTertiary)

            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .textStyle(.body)
                .foregroundStyle(Theme.foregroundPrimary)
                .focused($searchFocused)
                .onKeyPress(.upArrow) {
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.return) {
                    runSelected()
                    return .handled
                }
                .onKeyPress(.escape) {
                    onDismiss()
                    return .handled
                }
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                        row(item: item, index: index)
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedIndex = index
                                item.action()
                                onDismiss()
                            }
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
            .onChange(of: selectedIndex) { _, new in
                guard filtered.indices.contains(new) else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(filtered[new].id, anchor: .center)
                }
            }
        }
    }

    private func row(item: Item, index: Int) -> some View {
        let isSelected = index == selectedIndex

        return HStack(spacing: Spacing.sm) {
            // Left accent border for selected row
            Rectangle()
                .fill(isSelected ? Theme.accent : Color.clear)
                .frame(width: 4)

            if let icon = item.icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.foregroundSecondary)
                    .frame(width: 18)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .textStyle(.body)
                    .foregroundStyle(Theme.foregroundPrimary)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .textStyle(.caption)
                        .foregroundStyle(Theme.foregroundSecondary)
                }
            }

            Spacer(minLength: Spacing.sm)

            if let shortcut = item.shortcut {
                Text(shortcut)
                    .textStyle(.captionEmph)
                    .foregroundStyle(Theme.foregroundTertiary)
                    .padding(.horizontal, Spacing.xs)
            }
        }
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(isSelected ? Theme.accent.opacity(0.12) : Color.clear)
    }

    private func moveSelection(by delta: Int) {
        let items = filtered
        guard !items.isEmpty else { return }
        let next = selectedIndex + delta
        selectedIndex = min(max(next, 0), items.count - 1)
    }

    private func runSelected() {
        let items = filtered
        guard items.indices.contains(selectedIndex) else {
            onDismiss()
            return
        }
        items[selectedIndex].action()
        onDismiss()
    }
}

#Preview("SCCommand — light") {
    SCCommand(
        items: [
            .init(id: "new", title: "New Session", subtitle: "Start a fresh conversation", icon: "plus.circle", shortcut: "⌘N", action: {}),
            .init(id: "open", title: "Open Session…", subtitle: "Browse recent sessions", icon: "folder", shortcut: "⌘O", action: {}),
            .init(id: "search", title: "Search Messages", subtitle: "Find text across all sessions", icon: "magnifyingglass", shortcut: "⌘F", action: {}),
            .init(id: "settings", title: "Settings", subtitle: "Preferences and model config", icon: "gearshape", shortcut: "⌘,", action: {}),
            .init(id: "quit", title: "Quit SwiftClaw", icon: "power", shortcut: "⌘Q", action: {}),
        ],
        onDismiss: {}
    )
    .frame(width: 480, height: 320)
    .padding(Spacing.xl)
    .background(Theme.background)
}

#Preview("SCCommand — dark") {
    SCCommand(
        placeholder: "Run a command…",
        items: [
            .init(id: "a", title: "Toggle Sidebar", icon: "sidebar.left", shortcut: "⌘⇧S", action: {}),
            .init(id: "b", title: "Toggle Dark Mode", icon: "moon", action: {}),
            .init(id: "c", title: "Clear History", subtitle: "Remove all sessions", icon: "trash", action: {}),
        ],
        onDismiss: {}
    )
    .frame(width: 480, height: 320)
    .padding(Spacing.xl)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
