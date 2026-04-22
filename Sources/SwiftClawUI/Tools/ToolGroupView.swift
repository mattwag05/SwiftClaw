import SwiftUI

/// Collapsed card that groups a run of consecutive tool calls into a single
/// chat-row affordance. Header shows a "N tools used" summary with an overall
/// status pill; expanding reveals a per-item list with individual status pills
/// and (optionally) the output for each call.
public struct ToolGroupView: View {
    public struct Item: Identifiable, Sendable {
        public enum State: Sendable, Hashable {
            case running
            case done
            case error(message: String?)
            case denied
        }

        public let id: String
        public let toolName: String
        public let state: State
        public let output: String?

        public init(id: String, toolName: String, state: State, output: String? = nil) {
            self.id = id
            self.toolName = toolName
            self.state = state
            self.output = output
        }
    }

    private let items: [Item]
    @State private var isExpanded: Bool

    public init(items: [Item]) {
        self.items = items
        _isExpanded = State(initialValue: false)
    }

    /// Internal init so previews can render the expanded state without user
    /// interaction.
    init(items: [Item], initiallyExpanded: Bool) {
        self.items = items
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                Divider()
                    .background(Theme.borderSubtle)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.sm)
                itemsList
            }
        }
        .padding(Spacing.md)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    // MARK: - Header

    private var header: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "atom")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.foregroundSecondary)
                Text("\(items.count) tools used")
                    .textStyle(.monoLabel)
                    .foregroundStyle(Theme.foregroundSecondary)
                Spacer(minLength: Spacing.sm)
                if let overall = overallPillStatus {
                    SCStatusPill(overall)
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.foregroundTertiary)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(Text("\(items.count) tools used"))
        .accessibilityHint(Text(isExpanded ? "Collapse details" : "Expand details"))
    }

    // MARK: - Item rows

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(items) { item in
                ToolGroupRow(item: item)
            }
        }
    }

    // MARK: - Overall status

    private var overallPillStatus: SCStatusPill.Status? {
        guard !items.isEmpty else { return nil }
        if items.contains(where: { if case .error = $0.state { return true } else { return false } }) {
            return .error
        }
        if items.contains(where: { $0.state == .running }) {
            return .running
        }
        if items.contains(where: { $0.state == .denied }) {
            return .denied
        }
        return .done
    }
}

// MARK: - Row

private struct ToolGroupRow: View {
    let item: ToolGroupView.Item

    var body: some View {
        let category = ToolCategory(toolName: item.toolName)

        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                ToolIconView(toolName: item.toolName)
                HStack(spacing: 0) {
                    Text(item.toolName)
                        .textStyle(.body)
                        .foregroundStyle(Theme.foregroundPrimary)
                    Text(" · \(category.displayName)")
                        .textStyle(.caption)
                        .foregroundStyle(Theme.foregroundTertiary)
                }
                Spacer(minLength: Spacing.sm)
                SCStatusPill(item.state.pillStatus)
            }

            if let output = item.output, !output.isEmpty {
                DisclosureGroup {
                    Text(output)
                        .textStyle(.codeBlock)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Spacing.xs)
                        .padding(Spacing.sm)
                        .background(Theme.borderSubtle.opacity(0.5), in: RoundedRectangle(cornerRadius: Radius.sm))
                } label: {
                    Text("OUTPUT")
                        .textStyle(.monoLabel)
                        .foregroundStyle(Theme.foregroundTertiary)
                }
                .padding(.leading, Spacing.xl)
            }

            if case let .error(message) = item.state, let message, !message.isEmpty {
                Text(message)
                    .textStyle(.caption)
                    .foregroundStyle(Theme.destructive)
                    .padding(.leading, Spacing.xl)
            }
        }
    }
}

// MARK: - State → pill mapping

private extension ToolGroupView.Item.State {
    var pillStatus: SCStatusPill.Status {
        switch self {
        case .running: return .running
        case .done: return .done
        case .error: return .error
        case .denied: return .denied
        }
    }
}

// MARK: - Preview

private let previewItems: [ToolGroupView.Item] = [
    .init(id: "1", toolName: "read_file", state: .done, output: "line 1\nline 2\nline 3"),
    .init(id: "2", toolName: "grep", state: .done, output: "3 matches found"),
    .init(id: "3", toolName: "start_process", state: .running),
    .init(id: "4", toolName: "http_fetch", state: .error(message: "timeout after 30s"), output: nil),
    .init(id: "5", toolName: "mcp_pippin_digest", state: .denied),
]

#Preview("ToolGroupView — collapsed (light)") {
    ToolGroupView(items: previewItems)
        .padding(Spacing.xl)
        .frame(width: 520)
        .background(Theme.background)
        .preferredColorScheme(.light)
}

#Preview("ToolGroupView — expanded (light)") {
    ToolGroupView(items: previewItems, initiallyExpanded: true)
        .padding(Spacing.xl)
        .frame(width: 520)
        .background(Theme.background)
        .preferredColorScheme(.light)
}

#Preview("ToolGroupView — expanded (dark)") {
    ToolGroupView(items: previewItems, initiallyExpanded: true)
        .padding(Spacing.xl)
        .frame(width: 520)
        .background(Theme.background)
        .preferredColorScheme(.dark)
}
