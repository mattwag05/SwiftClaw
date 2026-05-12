import Foundation
import SwiftClawCore

/// Factory for all Build-mode tools.
///
/// Call `buildModeTools(workspaceURL:sessionId:allowlist:approvalDelegate:searchProvider:eventSink:)`
/// to get the full set of tools that register in a `.build` mode session.
///
/// These tools are SEPARATE from `SwiftClawToolFactory.allTools()` (which provides Chat tools).
/// Pippin tools are hidden in Build mode per the plan.
public enum BuildToolFactory {

    /// All Build-mode tools wired to the given workspace and collaborators.
    public static func buildModeTools(
        workspaceURL: URL,
        sessionId: String,
        allowlist: BashAllowlist,
        approvalDelegate: (any BashApprovalDelegate)? = nil,
        searchProvider: any SearchProvider = NullSearchProvider(),
        eventSink: (@Sendable (SessionEvent) -> Void)? = nil
    ) -> [any SwiftClawTool] {
        [
            // Workspace file tools
            BuildWriteFileTool(workspaceURL: workspaceURL, eventSink: eventSink),
            BuildReadFileTool(workspaceURL: workspaceURL),
            BuildEditFileTool(workspaceURL: workspaceURL),
            BuildListFilesTool(workspaceURL: workspaceURL),
            BuildDeleteFileTool(workspaceURL: workspaceURL),
            // Shell
            RunBashTool(workspaceURL: workspaceURL, allowlist: allowlist, approvalDelegate: approvalDelegate),
            // Canvas
            OpenPreviewTool(sessionId: sessionId),
            // Web
            WebSearchTool(provider: searchProvider),
            FetchURLTool(),
            // Math
            CalcTool(),
        ]
    }
}
