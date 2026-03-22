import Foundation
import SwiftClawCore

/// Centralized factory for all built-in SwiftClaw tools.
public enum SwiftClawToolFactory {
    /// Returns the 12 built-in tools (sysadmin + file + environment).
    /// Use ``processTools(monitor:)`` to additionally register process monitoring tools.
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

    /// Returns the 4 sentinel process monitoring tools bound to the given monitor.
    public static func processTools(monitor: ProcessMonitor) -> [any SwiftClawTool] {
        [
            StartProcessTool(monitor: monitor),
            ProcessOutputTool(monitor: monitor),
            StopProcessTool(monitor: monitor),
            ListMonitoredProcessesTool(monitor: monitor),
        ]
    }
}
