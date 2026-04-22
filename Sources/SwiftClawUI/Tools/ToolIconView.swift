import SwiftUI

/// Circular icon chip for a tool call. Uses the tool's `ToolCategory` to pick
/// both the SF Symbol and a muted tint wash so each tool reads as distinct at
/// a glance inside a grouped card.
public struct ToolIconView: View {
    public let toolName: String
    public let size: CGFloat

    public init(toolName: String, size: CGFloat = 14) {
        self.toolName = toolName
        self.size = size
    }

    public var body: some View {
        let category = ToolCategory(toolName: toolName)
        let diameter = size + Spacing.sm

        ZStack {
            Circle()
                .fill(category.tintColor.opacity(0.18))
                .frame(width: diameter, height: diameter)
            Image(systemName: category.iconSystemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(category.tintColor)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityLabel(Text(category.displayName))
    }
}

#Preview("ToolIconView — light") {
    HStack(spacing: Spacing.md) {
        ToolIconView(toolName: "read_file")
        ToolIconView(toolName: "start_process")
        ToolIconView(toolName: "http_fetch")
        ToolIconView(toolName: "memory_recall")
        ToolIconView(toolName: "mcp_pippin_digest")
        ToolIconView(toolName: "unknown_tool")
    }
    .padding(Spacing.xl)
    .background(Theme.surface)
    .preferredColorScheme(.light)
}

#Preview("ToolIconView — dark") {
    HStack(spacing: Spacing.md) {
        ToolIconView(toolName: "read_file", size: 18)
        ToolIconView(toolName: "start_process", size: 18)
        ToolIconView(toolName: "http_fetch", size: 18)
        ToolIconView(toolName: "memory_recall", size: 18)
        ToolIconView(toolName: "mcp_pippin_digest", size: 18)
        ToolIconView(toolName: "unknown_tool", size: 18)
    }
    .padding(Spacing.xl)
    .background(Theme.surface)
    .preferredColorScheme(.dark)
}
