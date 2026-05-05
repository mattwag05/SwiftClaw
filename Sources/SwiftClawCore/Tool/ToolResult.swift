/// Result of a tool execution, fed back to the LLM.
public struct ToolResult: Sendable, Codable {
    public let content: String
    public let isError: Bool

    public init(content: String, isError: Bool) {
        self.content = content
        self.isError = isError
    }

    public static func success(_ content: String) -> ToolResult {
        ToolResult(content: content, isError: false)
    }

    public static func failure(_ message: String) -> ToolResult {
        ToolResult(content: message, isError: true)
    }

    public func scrubbed(with proxy: any CredentialProxy) -> ToolResult {
        ToolResult(content: proxy.scrub(content), isError: isError)
    }
}
