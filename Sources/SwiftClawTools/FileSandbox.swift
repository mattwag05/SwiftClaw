import Foundation

/// Validates file system paths against an allowlist to prevent directory traversal.
public struct FileSandbox: Sendable {
    private let allowedPaths: [String]  // already expanded at init

    public init(allowedPaths: [String] = ["~"]) {
        let home = NSHomeDirectory()
        self.allowedPaths = allowedPaths.map { p in
            p.hasPrefix("~") ? home + p.dropFirst() : p
        }
    }

    /// Expands `~`, resolves symlinks, and checks that `path` is within an allowed prefix.
    /// Returns the resolved absolute path on success.
    @discardableResult
    public func validate(path: String) throws -> String {
        let expanded = expandTilde(path)
        guard !expanded.isEmpty else {
            throw FileSandboxError.pathEmpty
        }

        // Resolve symlinks before prefix check to prevent escape via symlink.
        let resolved = URL(fileURLWithPath: expanded).resolvingSymlinksInPath().path

        for allowed in allowedPaths {
            let prefix = allowed.hasSuffix("/") ? allowed : allowed + "/"
            if resolved == allowed || resolved.hasPrefix(prefix) {
                return resolved
            }
        }

        throw FileSandboxError.pathNotAllowed(resolved)
    }

    private func expandTilde(_ path: String) -> String {
        guard path.hasPrefix("~") else { return path }
        return NSHomeDirectory() + path.dropFirst()
    }
}

public enum FileSandboxError: LocalizedError {
    case pathEmpty
    case pathNotAllowed(String)

    public var errorDescription: String? {
        switch self {
        case .pathEmpty:
            "Path must not be empty"
        case let .pathNotAllowed(path):
            "Path '\(path)' is not within any allowed directory"
        }
    }
}
