import Foundation

/// Metadata about a saved session.
public struct SessionMetadata: Codable, Sendable {
    public let agentName: String
    public let modelId: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(agentName: String, modelId: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.agentName = agentName
        self.modelId = modelId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Summary entry for listing sessions.
public struct SessionSummary: Codable, Sendable {
    public let sessionId: String
    public let agentName: String
    public let messageCount: Int
    public let updatedAt: Date
    public let preview: String  // First user message, truncated

    public init(sessionId: String, agentName: String, messageCount: Int, updatedAt: Date, preview: String) {
        self.sessionId = sessionId
        self.agentName = agentName
        self.messageCount = messageCount
        self.updatedAt = updatedAt
        self.preview = preview
    }
}

/// Protocol for saving and loading session conversation history.
public protocol SessionStore: Sendable {
    func save(sessionId: String, messages: [Message], metadata: SessionMetadata) async throws
    func load(sessionId: String) async throws -> (messages: [Message], metadata: SessionMetadata)
    func list() async throws -> [SessionSummary]
    func delete(sessionId: String) async throws
}
