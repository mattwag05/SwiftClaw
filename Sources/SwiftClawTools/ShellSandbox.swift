import Foundation

/// Validates shell commands against an allowlist before execution.
/// Rejects dangerous patterns: pipes, redirects, command substitution, chaining.
public struct ShellSandbox: Sendable {
    public static let defaultAllowlist: Set<String> = [
        "ls", "cat", "head", "tail", "wc", "df", "du", "find", "grep",
        "ps", "top", "uptime", "whoami", "hostname", "uname", "sw_vers",
        "which", "file", "stat", "date", "echo", "pwd", "env", "printenv",
        "sysctl", "diskutil", "system_profiler", "ioreg",
    ]

    /// Characters/patterns that indicate shell injection or path traversal attempts.
    private static let dangerousPatterns: [String] = [
        "|", ";", "&&", "||", "`", "$(", ">", "<", "../", "/..",
    ]

    let allowlist: Set<String>

    public init(allowlist: Set<String>? = nil) {
        self.allowlist = allowlist ?? Self.defaultAllowlist
    }

    /// Validate a command string. Returns the executable path and arguments if safe.
    public func validate(command: String) throws -> (executable: String, arguments: [String]) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ShellSandboxError.emptyCommand
        }

        // Check for dangerous patterns
        for pattern in Self.dangerousPatterns {
            if trimmed.contains(pattern) {
                throw ShellSandboxError.dangerousPattern(pattern)
            }
        }

        // Split into command + arguments
        let components = trimmed.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard let commandName = components.first else {
            throw ShellSandboxError.emptyCommand
        }

        // Extract the base command name (strip path)
        let baseName = (commandName as NSString).lastPathComponent

        guard allowlist.contains(baseName) else {
            throw ShellSandboxError.commandNotAllowed(baseName)
        }

        // Resolve the full path via /usr/bin/which
        let resolvedPath = try resolveCommand(baseName)

        return (executable: resolvedPath, arguments: Array(components.dropFirst()))
    }

    private func resolveCommand(_ name: String) throws -> String {
        // Check standard paths first
        let standardPaths = [
            "/usr/bin/\(name)",
            "/bin/\(name)",
            "/usr/sbin/\(name)",
            "/sbin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
        ]
        for path in standardPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        throw ShellSandboxError.commandNotFound(name)
    }
}

public enum ShellSandboxError: LocalizedError {
    case emptyCommand
    case dangerousPattern(String)
    case commandNotAllowed(String)
    case commandNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .emptyCommand:
            "Empty command"
        case let .dangerousPattern(pattern):
            "Command contains disallowed pattern: '\(pattern)'"
        case let .commandNotAllowed(name):
            "Command '\(name)' is not in the allowlist"
        case let .commandNotFound(name):
            "Command '\(name)' not found in standard paths"
        }
    }
}
