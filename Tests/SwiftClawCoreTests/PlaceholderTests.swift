import Foundation
import Testing
@testable import SwiftClawCore

@Test func versionExists() {
    #expect(!SwiftClawVersion.version.isEmpty)
    #expect(SwiftClawVersion.version == "0.1.0-beta")
}

// MARK: - Message Tests

@Test func messageCreation() {
    let msg = Message(role: .user, content: "hello")
    #expect(msg.role == .user)
    #expect(msg.content == "hello")
    #expect(msg.toolCalls == nil)
    #expect(msg.toolCallId == nil)
}

@Test func messageWithToolCalls() {
    let call = ToolCallRequest(id: "1", name: "test", arguments: "{}")
    let msg = Message(role: .assistant, content: "", toolCalls: [call])
    #expect(msg.toolCalls?.count == 1)
    #expect(msg.toolCalls?.first?.name == "test")
}

@Test func toolResultMessage() {
    let msg = Message(role: .tool, content: "result", toolCallId: "1")
    #expect(msg.role == .tool)
    #expect(msg.toolCallId == "1")
}

// MARK: - ToolCallRequest Tests

@Test func toolCallRequestEquality() {
    let a = ToolCallRequest(id: "1", name: "foo", arguments: "{\"x\":1}")
    let b = ToolCallRequest(id: "1", name: "foo", arguments: "{\"x\":1}")
    #expect(a == b)
}

@Test func toolCallRequestCodable() throws {
    let original = ToolCallRequest(id: "abc", name: "test_tool", arguments: "{\"query\":\"hello\"}")
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(ToolCallRequest.self, from: data)
    #expect(decoded == original)
}

// MARK: - JSONSchema Tests

@Test func jsonSchemaStringEncode() throws {
    let schema = JSONSchema.string(description: "A name")
    let data = try JSONEncoder().encode(schema)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(json?["type"] as? String == "string")
    #expect(json?["description"] as? String == "A name")
}

@Test func jsonSchemaObjectEncode() throws {
    let schema = JSONSchema.object(
        properties: [
            "name": .string(description: "User name"),
            "age": .integer(description: "User age"),
        ],
        required: ["name"]
    )
    let data = try JSONEncoder().encode(schema)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(json?["type"] as? String == "object")
    let required = json?["required"] as? [String]
    #expect(required == ["name"])
}

@Test func jsonSchemaRoundTrip() throws {
    let original = JSONSchema.object(
        properties: [
            "query": .string(description: "Search query"),
            "limit": .integer(description: nil),
            "tags": .array(items: .string(description: nil), description: "Tag list"),
        ],
        required: ["query"]
    )
    let encoder = JSONEncoder()
    let data = try encoder.encode(original)
    let decoded = try JSONDecoder().decode(JSONSchema.self, from: data)
    #expect(decoded == original)
}

@Test func jsonSchemaEnumerationRoundTrip() throws {
    let original = JSONSchema.enumeration(values: ["asc", "desc"], description: "Sort order")
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(JSONSchema.self, from: data)
    #expect(decoded == original)
}

// MARK: - ToolResult Tests

@Test func toolResultSuccess() {
    let r = ToolResult.success("ok")
    #expect(r.content == "ok")
    #expect(!r.isError)
}

@Test func toolResultFailure() {
    let r = ToolResult.failure("bad")
    #expect(r.content == "bad")
    #expect(r.isError)
}

// MARK: - ToolRegistry Tests

struct EchoTool: SwiftClawTool {
    let name = "echo"
    let description = "Echoes input"
    let parameterSchema: JSONSchema = .object(
        properties: ["text": .string(description: "Text to echo")],
        required: ["text"]
    )

    func execute(arguments: String) async throws -> ToolResult {
        struct Args: Decodable { var text: String }
        let args = try JSONDecoder().decode(Args.self, from: Data(arguments.utf8))
        return .success(args.text)
    }
}

@Test func toolRegistryLookup() {
    let registry = ToolRegistry(tools: [EchoTool()])
    #expect(registry.tool(named: "echo") != nil)
    #expect(registry.tool(named: "nonexistent") == nil)
    #expect(registry.toolNames == ["echo"])
}

@Test func toolRegistryDefinitions() {
    let registry = ToolRegistry(tools: [EchoTool()])
    #expect(registry.definitions.count == 1)
    #expect(registry.definitions.first?.name == "echo")
}

@Test func toolRegistryExecute() async throws {
    let registry = ToolRegistry(tools: [EchoTool()])
    let result = try await registry.execute(name: "echo", arguments: "{\"text\":\"hello\"}")
    #expect(result.content == "hello")
    #expect(!result.isError)
}

@Test func toolRegistryUnknownTool() async throws {
    let registry = ToolRegistry(tools: [])
    let result = try await registry.execute(name: "missing", arguments: "{}")
    #expect(result.isError)
    #expect(result.content.contains("Unknown tool"))
}

// MARK: - Agent Tests

@Test func agentCreation() {
    let agent = Agent(configuration: AgentConfiguration(
        name: "TestAgent",
        systemPrompt: "You are a test agent.",
        tools: [EchoTool()],
        modelId: "test-model"
    ))
    #expect(agent.configuration.name == "TestAgent")
    #expect(agent.toolRegistry.toolNames == ["echo"])
}

// MARK: - Session Tests with Mock Backend

struct MockBackend: ModelBackend {
    let responses: [GenerationResponse]
    var callIndex = 0

    func generate(
        messages: [Message],
        tools: [ToolDefinition],
        config: GenerationConfig
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        // Find which response to return based on message count
        // Simple heuristic: count non-system messages to determine round
        let nonSystem = messages.filter { $0.role != .system }
        let roundIndex = max(0, (nonSystem.count - 1) / 2) // Rough approximation
        let idx = min(roundIndex, responses.count - 1)
        let response = responses[idx]

        return AsyncThrowingStream { continuation in
            if !response.content.isEmpty {
                continuation.yield(StreamChunk(text: response.content))
            }
            continuation.yield(StreamChunk(
                toolCalls: response.toolCalls.isEmpty ? nil : response.toolCalls,
                finishReason: response.finishReason
            ))
            continuation.finish()
        }
    }
}

@Test func sessionSimpleResponse() async throws {
    let backend = MockBackend(responses: [
        GenerationResponse(content: "Hello!", finishReason: .stop)
    ])

    let agent = Agent(configuration: AgentConfiguration(
        name: "Test", systemPrompt: "Test", tools: [], modelId: "mock"
    ))

    let session = Session(agent: agent, backend: backend)
    var text = ""
    var gotDone = false

    let events = await session.respond(to: "Hi")
    for try await event in events {
        switch event {
        case let .turn(response):
            text = response.content
        case .done:
            gotDone = true
        default:
            break
        }
    }

    #expect(text == "Hello!")
    #expect(gotDone)
}

@Test func sessionWithToolCall() async throws {
    let backend = MockBackend(responses: [
        // First response: tool call
        GenerationResponse(
            content: "",
            toolCalls: [ToolCallRequest(id: "1", name: "echo", arguments: "{\"text\":\"world\"}")],
            finishReason: .toolCall
        ),
        // Second response: final answer after tool result
        GenerationResponse(content: "Echo said: world", finishReason: .stop),
    ])

    let agent = Agent(configuration: AgentConfiguration(
        name: "Test", systemPrompt: "Test", tools: [EchoTool()], modelId: "mock"
    ))

    let session = Session(agent: agent, backend: backend)
    var finalText = ""
    var toolCalled = false

    let events = await session.respond(to: "echo world")
    for try await event in events {
        switch event {
        case .toolCallStart(_, let name):
            if name == "echo" { toolCalled = true }
        case let .turn(response):
            finalText = response.content
        default:
            break
        }
    }

    #expect(toolCalled)
    #expect(finalText == "Echo said: world")
}

// MARK: - Error Tests

@Test func swiftClawErrorDescriptions() {
    let errors: [(SwiftClawError, String)] = [
        (.modelLoadFailed("test"), "Failed to load model: test"),
        (.generationFailed("oops"), "Generation failed: oops"),
        (.maxToolRoundTripsExceeded(5), "Exceeded maximum tool round-trips (5)"),
        (.toolExecutionFailed(toolName: "foo", detail: "bar"), "Tool 'foo' failed: bar"),
        (.sessionClosed, "Session is closed"),
    ]
    for (error, expected) in errors {
        #expect(error.localizedDescription == expected)
    }
}
