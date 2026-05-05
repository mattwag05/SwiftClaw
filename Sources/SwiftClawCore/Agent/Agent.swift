/// An agent: immutable configuration paired with a tool registry.
///
/// Agents are value types with no mutable state. The `Session` actor
/// manages all mutable conversation state during execution.
public struct Agent: Sendable {
    public let configuration: AgentConfiguration
    public let toolRegistry: ToolRegistry

    public init(configuration: AgentConfiguration) {
        self.configuration = configuration
        toolRegistry = ToolRegistry(tools: configuration.tools, proxy: configuration.credentialProxy)
    }
}
