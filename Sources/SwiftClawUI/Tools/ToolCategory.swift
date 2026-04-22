import SwiftUI

/// Semantic categorization of a tool call by name. Drives icon + tint in the
/// grouped tool card and per-row ornaments in expanded state.
///
/// The classifier does case-insensitive substring matching in a fixed priority
/// order (filesystem → shell → web → memory → mcp → generic). First match wins,
/// so tools with overlapping keywords land in the earliest applicable bucket.
public enum ToolCategory: Sendable, Hashable {
    case filesystem
    case shell
    case web
    case memory
    case mcp
    case generic

    /// Classify a tool by its raw name. Case-insensitive substring match in the
    /// order defined above.
    public init(toolName: String) {
        let lower = toolName.lowercased()

        // Filesystem
        let filesystemKeywords = [
            "file", "read", "write", "edit", "delete",
            "glob", "find_files", "grep",
        ]
        if filesystemKeywords.contains(where: { lower.contains($0) }) {
            self = .filesystem
            return
        }

        // Shell
        let shellKeywords = ["shell", "run", "process", "exec", "kill", "start_process"]
        if shellKeywords.contains(where: { lower.contains($0) }) {
            self = .shell
            return
        }

        // Web
        let webKeywords = ["http", "fetch", "web", "url", "download"]
        if webKeywords.contains(where: { lower.contains($0) }) {
            self = .web
            return
        }

        // Memory
        if lower.contains("memory") {
            self = .memory
            return
        }

        // MCP
        if lower.contains("mcp_") || lower.contains("pippin_") {
            self = .mcp
            return
        }

        self = .generic
    }

    /// SF Symbol name for the category.
    public var iconSystemName: String {
        switch self {
        case .filesystem: return "folder"
        case .shell: return "terminal"
        case .web: return "network"
        case .memory: return "brain"
        case .mcp: return "link"
        case .generic: return "wrench.and.screwdriver"
        }
    }

    /// Tint color used for the icon background wash and category tag.
    public var tintColor: Color {
        switch self {
        case .filesystem: return Theme.accent
        case .shell: return Theme.foregroundPrimary
        case .web: return Theme.accentSecondary
        case .memory: return .purple
        case .mcp: return Theme.warning
        case .generic: return Theme.foregroundSecondary
        }
    }

    /// Human-readable label for the category tag.
    public var displayName: String {
        switch self {
        case .filesystem: return "Filesystem"
        case .shell: return "Shell"
        case .web: return "Web"
        case .memory: return "Memory"
        case .mcp: return "MCP"
        case .generic: return "Tool"
        }
    }
}
