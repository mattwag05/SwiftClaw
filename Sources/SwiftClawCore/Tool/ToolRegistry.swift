/// Lookup table mapping tool names to their implementations.
public struct ToolRegistry: Sendable {
    private let tools: [String: any SwiftClawTool]

    public init(tools: [any SwiftClawTool]) {
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
    }

    public var definitions: [ToolDefinition] {
        tools.values.map(\.definition)
    }

    public var toolNames: [String] {
        tools.keys.sorted()
    }

    public func tool(named name: String) -> (any SwiftClawTool)? {
        tools[name]
    }

    public func execute(name: String, arguments: String) async throws -> ToolResult {
        guard let tool = tools[name] else {
            return .failure("Unknown tool: \(name)")
        }
        return try await tool.execute(arguments: arguments)
    }
}
