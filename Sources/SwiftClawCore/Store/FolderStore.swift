import Foundation

/// JSON-backed folder store at `~/.swiftclaw/folders.json`. Operations are
/// serialized through the actor; `list()` reflects the in-memory cache and is
/// populated lazily from disk on first access.
public actor FolderStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var cache: [Folder]?

    public init(baseDir: URL? = nil) throws {
        let base = baseDir ?? FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".swiftclaw")
        fileURL = base.appendingPathComponent("folders.json")

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        decoder = dec

        try FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )
    }

    public func list() async throws -> [Folder] {
        try loadIfNeeded()
        return (cache ?? []).sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.createdAt < rhs.createdAt
        }
    }

    @discardableResult
    public func create(name: String) async throws -> Folder {
        try loadIfNeeded()
        var folders = cache ?? []
        let nextOrder = (folders.map(\.order).max() ?? -1) + 1
        let folder = Folder(name: name, order: nextOrder)
        folders.append(folder)
        try persist(folders)
        return folder
    }

    public func rename(id: UUID, to newName: String) async throws {
        try loadIfNeeded()
        var folders = cache ?? []
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].name = newName
        try persist(folders)
    }

    public func delete(id: UUID) async throws {
        try loadIfNeeded()
        var folders = cache ?? []
        folders.removeAll { $0.id == id }
        try persist(folders)
    }

    public func reorder(ids: [UUID]) async throws {
        try loadIfNeeded()
        var folders = cache ?? []
        let orderMap = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        for i in folders.indices {
            if let newOrder = orderMap[folders[i].id] {
                folders[i].order = newOrder
            }
        }
        try persist(folders)
    }

    // MARK: - Internals

    private func loadIfNeeded() throws {
        if cache != nil { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cache = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            cache = try decoder.decode([Folder].self, from: data)
        } catch {
            throw SwiftClawError.storageError("Folder read failed: \(error.localizedDescription)")
        }
    }

    private func persist(_ folders: [Folder]) throws {
        cache = folders
        do {
            let data = try encoder.encode(folders)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw SwiftClawError.storageError("Folder write failed: \(error.localizedDescription)")
        }
    }
}
