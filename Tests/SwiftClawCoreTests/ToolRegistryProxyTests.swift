@testable import SwiftClawCore
import Testing

// MARK: - Helpers

private struct EchoArgsTool: SwiftClawTool {
    let name = "echo_args"
    let description = "Returns its arguments verbatim."
    let parameterSchema: JSONSchema = .object(properties: [:], required: [])
    let requiresConfirmation = false
    func execute(arguments: String) async throws -> ToolResult {
        .success(arguments)
    }
}

private struct FixedOutputTool: SwiftClawTool {
    let name = "fixed_output"
    let description = "Returns a fixed string."
    let parameterSchema: JSONSchema = .object(properties: [:], required: [])
    let requiresConfirmation = false
    let output: String
    func execute(arguments _: String) async throws -> ToolResult {
        .success(output)
    }
}

@Suite("ToolRegistry credential proxy")
struct ToolRegistryProxyTests {
    @Test("Result containing GitHub PAT is redacted")
    func resultRedacted() async throws {
        let token = "ghp_" + String(repeating: "A", count: 36)
        let registry = ToolRegistry(
            tools: [FixedOutputTool(output: "token=\(token)")],
            proxy: RegexCredentialProxy()
        )
        let result = try await registry.execute(name: "fixed_output", arguments: "{}")
        #expect(result.content.contains("[REDACTED:github]"))
        #expect(!result.content.contains(token))
    }

    @Test("Arguments containing AWS key are scrubbed before tool sees them")
    func argumentsRedacted() async throws {
        let awsKey = "AKIAIOSFODNN7EXAMPLE"
        let registry = ToolRegistry(
            tools: [EchoArgsTool()],
            proxy: RegexCredentialProxy()
        )
        let result = try await registry.execute(name: "echo_args", arguments: "{\"key\":\"\(awsKey)\"}")
        #expect(result.content.contains("[REDACTED:aws_key]"))
        #expect(!result.content.contains(awsKey))
    }

    @Test("NoOpCredentialProxy leaves result unchanged")
    func noOpPassthrough() async throws {
        let token = "ghp_" + String(repeating: "B", count: 36)
        let registry = ToolRegistry(
            tools: [FixedOutputTool(output: "token=\(token)")],
            proxy: NoOpCredentialProxy()
        )
        let result = try await registry.execute(name: "fixed_output", arguments: "{}")
        #expect(result.content.contains(token))
    }

    @Test("Default init uses no-op proxy — existing callers unaffected")
    func defaultInitNoOp() async throws {
        let registry = ToolRegistry(tools: [FixedOutputTool(output: "hello")])
        let result = try await registry.execute(name: "fixed_output", arguments: "{}")
        #expect(result.content == "hello")
    }

    @Test("Unknown tool returns failure without crashing")
    func unknownTool() async throws {
        let registry = ToolRegistry(tools: [], proxy: RegexCredentialProxy())
        let result = try await registry.execute(name: "nonexistent", arguments: "{}")
        #expect(result.isError)
    }
}
