import Foundation

/// Path-validation utilities that prevent tools from escaping a workspace directory.
///
/// All Build-mode file tools pass target paths through `assertInWorkspace` before
/// reading or writing. The sandbox does not rely on OS-level sandboxing; it is a
/// defence-in-depth check at the Swift layer.
public struct WorkspaceSandbox: Sendable {

    /// Throws `storageError` if `target` is not a descendant of `base`.
    ///
    /// Uses `standardizedFileURL` to resolve `..` components, symlinks included
    /// in the path string, and trailing slashes before comparing.
    public static func assertInWorkspace(base: URL, target: URL) throws {
        let basePath = base.standardizedFileURL.path
        let targetPath = target.standardizedFileURL.path
        // Target must equal base exactly OR be a proper descendant (starts with basePath + "/")
        guard targetPath == basePath || targetPath.hasPrefix(basePath + "/") else {
            throw SwiftClawError.storageError(
                "Path '\(targetPath)' escapes workspace '\(basePath)'"
            )
        }
    }

    /// Resolves `relativePath` against `workspaceBase`, then validates it stays
    /// inside the workspace. Returns the absolute URL.
    ///
    /// Absolute paths are accepted only when they fall inside the workspace.
    public static func resolve(path relativePath: String, in workspaceBase: URL) throws -> URL {
        let raw: URL
        if relativePath.hasPrefix("/") {
            raw = URL(fileURLWithPath: relativePath)
        } else {
            raw = workspaceBase.appendingPathComponent(relativePath)
        }
        try assertInWorkspace(base: workspaceBase, target: raw)
        return raw.standardizedFileURL
    }
}
