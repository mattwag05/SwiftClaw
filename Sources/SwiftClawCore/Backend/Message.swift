import Foundation

public enum MessageRole: String, Sendable, Codable {
    case system
    case user
    case assistant
    case tool
}

public struct ToolCallRequest: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    /// JSON-encoded arguments string. Each tool deserializes into its own Codable type.
    public let arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

public struct Message: Sendable, Codable {
    public let role: MessageRole
    public let content: String
    public let toolCalls: [ToolCallRequest]?
    public let toolCallId: String?

    public init(
        role: MessageRole,
        content: String,
        toolCalls: [ToolCallRequest]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
}
