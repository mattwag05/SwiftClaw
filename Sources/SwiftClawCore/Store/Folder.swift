import Foundation

/// A user-defined folder that groups sessions. Sessions reference a folder by
/// `SessionMetadata.folderID`; the folder itself lives in `FolderStore`.
public struct Folder: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var order: Int
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        order: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.createdAt = createdAt
    }
}
