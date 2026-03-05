/// Lookup table mapping tool names to their implementations.
public struct ToolRegistry: Sendable {
    private let tools: [String: any SwiftClawTool]

    public init(tools: [any SwiftClawTool]) {
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
    }

    public var definitions: [ToolDefinition] {
        tools.values.map(\.definition).sorted { $0.name < $1.name }
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
        do {
            return try await tool.execute(arguments: arguments)
        } catch {
            return .failure(SwiftClawError.toolExecutionFailed(toolName: name, detail: error.localizedDescription).errorDescription ?? error.localizedDescription)
        }
    }
}
