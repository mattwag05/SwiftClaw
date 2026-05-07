import Foundation

/// Metadata about a saved session.
public struct SessionMetadata: Codable, Sendable {
    public let agentName: String
    public let modelId: String
    public let createdAt: Date
    public var updatedAt: Date

    // Organization fields. Additive since v2026-04; older session files
    // decode without them (see the custom decoder below).
    public var title: String?
    public var isPinned: Bool
    public var pinnedAt: Date?
    public var folderID: UUID?
    public var tags: [String]

    // Build-mode fields. Additive since v2026-05 (Gemma port).
    /// Chat or Build mode. Defaults to `.chat` for pre-existing sessions.
    public var mode: SessionMode
    /// HSplitView divider position for the canvas (0.0–1.0). Persisted per-session.
    public var canvasSplit: Double
    /// User-provided system-prompt override for this session. `nil` = use default.
    public var systemPromptOverride: String?

    public init(
        agentName: String,
        modelId: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        title: String? = nil,
        isPinned: Bool = false,
        pinnedAt: Date? = nil,
        folderID: UUID? = nil,
        tags: [String] = [],
        mode: SessionMode = .chat,
        canvasSplit: Double = 0.5,
        systemPromptOverride: String? = nil
    ) {
        self.agentName = agentName
        self.modelId = modelId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
        self.folderID = folderID
        self.tags = tags
        self.mode = mode
        self.canvasSplit = canvasSplit
        self.systemPromptOverride = systemPromptOverride
    }

    enum CodingKeys: String, CodingKey {
        case agentName, modelId, createdAt, updatedAt
        case title, isPinned, pinnedAt, folderID, tags
        case mode, canvasSplit, systemPromptOverride
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        agentName = try c.decode(String.self, forKey: .agentName)
        modelId = try c.decode(String.self, forKey: .modelId)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        pinnedAt = try c.decodeIfPresent(Date.self, forKey: .pinnedAt)
        folderID = try c.decodeIfPresent(UUID.self, forKey: .folderID)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        mode = try c.decodeIfPresent(SessionMode.self, forKey: .mode) ?? .chat
        canvasSplit = try c.decodeIfPresent(Double.self, forKey: .canvasSplit) ?? 0.5
        systemPromptOverride = try c.decodeIfPresent(String.self, forKey: .systemPromptOverride)
    }
}

/// Summary entry for listing sessions. Mirrors the organization fields from
/// `SessionMetadata` so the session list can filter and group without loading
/// the full message history.
public struct SessionSummary: Codable, Sendable, Identifiable {
    public var id: String {
        sessionId
    }

    public let sessionId: String
    public let agentName: String
    public let messageCount: Int
    public let updatedAt: Date
    public let preview: String

    public let title: String?
    public let isPinned: Bool
    public let pinnedAt: Date?
    public let folderID: UUID?
    public let tags: [String]

    public init(
        sessionId: String,
        agentName: String,
        messageCount: Int,
        updatedAt: Date,
        preview: String,
        title: String? = nil,
        isPinned: Bool = false,
        pinnedAt: Date? = nil,
        folderID: UUID? = nil,
        tags: [String] = []
    ) {
        self.sessionId = sessionId
        self.agentName = agentName
        self.messageCount = messageCount
        self.updatedAt = updatedAt
        self.preview = preview
        self.title = title
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
        self.folderID = folderID
        self.tags = tags
    }

    /// Display-friendly title: falls back to the first user message preview.
    public var displayTitle: String {
        if let title, !title.isEmpty { return title }
        if !preview.isEmpty { return preview }
        return "New chat"
    }
}

/// Protocol for saving and loading session conversation history.
public protocol SessionStore: Sendable {
    func save(sessionId: String, messages: [Message], metadata: SessionMetadata) async throws
    func load(sessionId: String) async throws -> (messages: [Message], metadata: SessionMetadata)
    func list() async throws -> [SessionSummary]
    func delete(sessionId: String) async throws

    /// Read-modify-write on a single session's metadata. Implementations must
    /// serialize this against `list()` / `save()` to avoid lost updates.
    func updateMetadata(sessionId: String, _ transform: @Sendable (inout SessionMetadata) -> Void) async throws
}
