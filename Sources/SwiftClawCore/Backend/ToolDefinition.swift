/// Tool definition sent to the LLM as part of the tool-use prompt.
public struct ToolDefinition: Sendable, Codable {
    public let name: String
    public let description: String
    public let parameters: JSONSchema

    public init(name: String, description: String, parameters: JSONSchema) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}
