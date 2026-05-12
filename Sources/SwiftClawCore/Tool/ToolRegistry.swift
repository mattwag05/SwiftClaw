import Foundation

/// Lookup table mapping tool names to their implementations.
public struct ToolRegistry: Sendable {
    private let tools: [String: any SwiftClawTool]
    private let proxy: any CredentialProxy

    public init(tools: [any SwiftClawTool], proxy: any CredentialProxy = NoOpCredentialProxy()) {
        var dict: [String: any SwiftClawTool] = [:]
        for tool in tools {
            if dict[tool.name] != nil {
                // Dictionary(uniqueKeysWithValues:) would crash on duplicates — warn instead and keep first.
                fputs("[SwiftClaw] Warning: duplicate tool name '\(tool.name)' — keeping first registration\n", stderr)
            } else {
                dict[tool.name] = tool
            }
        }
        self.tools = dict
        self.proxy = proxy
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
        let scrubbedArgs = proxy.scrub(arguments)
        do {
            let result = try await tool.execute(arguments: scrubbedArgs)
            return result.scrubbed(with: proxy)
        } catch {
            return .failure(SwiftClawError.toolExecutionFailed(toolName: name, detail: error.localizedDescription).errorDescription ?? error.localizedDescription)
        }
    }
}
