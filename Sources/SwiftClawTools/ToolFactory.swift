import Foundation
import SwiftClawCore

/// Centralized factory for all built-in SwiftClaw tools.
public enum SwiftClawToolFactory {
    /// Returns all 12 built-in tools (sysadmin + file + environment).
    /// Constructs a `FileSandbox` from the config and injects it into file tools.
    public static func allTools(config: SwiftClawConfig = .default) -> [any SwiftClawTool] {
        let sandbox = FileSandbox(allowedPaths: config.fileSandbox.allowedPaths)
        return [
            // Sysadmin tools
            SystemInfoTool(),
            DiskSpaceTool(),
            ProcessListTool(),
            ShellTool(),
            // File tools
            ReadFileTool(sandbox: sandbox),
            WriteFileTool(sandbox: sandbox),
            EditFileTool(sandbox: sandbox),
            ListDirectoryTool(sandbox: sandbox),
            FindFilesTool(sandbox: sandbox),
            // Environment tools
            EnvVarsTool(),
            DateTimeTool(),
            ClipboardTool(),
        ]
    }
}
