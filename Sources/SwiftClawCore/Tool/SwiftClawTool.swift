/// Protocol for tools that can be called by an agent during a session.
///
/// Each tool exposes its name, description, and parameter schema to the LLM,
/// and deserializes the JSON arguments string in its own `execute` implementation.
public protocol SwiftClawTool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameterSchema: JSONSchema { get }

    func execute(arguments: String) async throws -> ToolResult
}

extension SwiftClawTool {
    /// Produces the `ToolDefinition` sent to the LLM.
    public var definition: ToolDefinition {
        ToolDefinition(name: name, description: description, parameters: parameterSchema)
    }
}
