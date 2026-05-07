import Foundation

/// Manages per-session workspace directories at `~/.swiftclaw/workspaces/<sessionID>/`.
///
/// Build-mode file tools and `run_bash` operate inside this directory.
/// The manager handles creation, deletion, promotion (moving to a user-chosen path),
/// and the "is empty?" check used to decide whether to prompt before deleting.
public actor WorkspaceManager {
    private let baseDir: URL

    public static let defaultBaseDir: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".swiftclaw")
        .appendingPathComponent("workspaces")

    public init(baseDir: URL? = nil) throws {
        let dir = baseDir ?? Self.defaultBaseDir
        self.baseDir = dir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// URL of the workspace directory for `sessionId`. Does not create it.
    public func path(for sessionId: String) -> URL {
        baseDir.appendingPathComponent(sessionId)
    }

    /// Creates the workspace directory for `sessionId` if it doesn't exist.
    /// Returns the workspace URL.
    @discardableResult
    public func create(sessionId: String) throws -> URL {
        let dir = path(for: sessionId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Returns `true` if the workspace for `sessionId` exists but contains no files.
    public func isEmpty(sessionId: String) -> Bool {
        let dir = path(for: sessionId)
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            return true  // Doesn't exist → treat as empty
        }
        return contents.isEmpty
    }

    /// Deletes the workspace directory for `sessionId`.
    public func delete(sessionId: String) throws {
        let dir = path(for: sessionId)
        guard FileManager.default.fileExists(atPath: dir.path) else { return }
        try FileManager.default.removeItem(at: dir)
    }

    /// Moves the workspace to `destination` ("Promote to project…" command).
    /// If `destination` is an existing directory the workspace contents are merged into it.
    public func promote(sessionId: String, to destination: URL) throws {
        let src = path(for: sessionId)
        guard FileManager.default.fileExists(atPath: src.path) else {
            throw SwiftClawError.storageError("Workspace for \(sessionId) does not exist")
        }
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            // Merge: move each item in src into destination
            let items = try FileManager.default.contentsOfDirectory(
                at: src, includingPropertiesForKeys: nil
            )
            for item in items {
                let target = destination.appendingPathComponent(item.lastPathComponent)
                try FileManager.default.moveItem(at: item, to: target)
            }
            try FileManager.default.removeItem(at: src)
        } else {
            try FileManager.default.moveItem(at: src, to: destination)
        }
    }
}
