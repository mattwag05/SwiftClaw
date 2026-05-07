import Foundation
@testable import SwiftClawCore
import Testing

// MARK: - Mock XML Backend

/// Backend that emits text chunks (not structured tool_calls) and identifies
/// itself as using the XML tool protocol.
private struct XMLTextBackend: ModelBackend {
    var preferredToolProtocol: ToolProtocol { .xml }

    /// Each element is the full text the backend emits for one round-trip.
    let rounds: [String]

    func generate(
        messages: [Message],
        tools _: [ToolDefinition],
        config _: GenerationConfig
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        // Determine which round we're on by counting assistant messages.
        let assistantCount = messages.filter { $0.role == .assistant }.count
        let idx = min(assistantCount, rounds.count - 1)
        let text = rounds[idx]

        return AsyncThrowingStream { continuation in
            if !text.isEmpty {
                continuation.yield(StreamChunk(text: text))
            }
            continuation.yield(StreamChunk(finishReason: .stop))
            continuation.finish()
        }
    }
}

// MARK: - Echo tool (reused from PlaceholderTests via the same target)

private struct XMLEchoTool: SwiftClawTool {
    let name = "xml_echo"
    let description = "Echoes the input text"
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

// MARK: - Tests

@Suite("Session+XMLDispatch")
struct SessionXMLDispatchTests {

    private func makeSession(
        rounds: [String],
        tools: [any SwiftClawTool] = []
    ) -> Session {
        let backend = XMLTextBackend(rounds: rounds)
        let agent = Agent(configuration: AgentConfiguration(
            name: "XMLAgent",
            systemPrompt: "You are a helpful assistant.",
            tools: tools,
            modelId: "xml-mock"
        ))
        return Session(agent: agent, backend: backend)
    }

    @Test func xmlRouteSelectedForXMLBackend() async throws {
        // Verify the XML dispatch path is chosen when preferredToolProtocol == .xml
        let session = makeSession(rounds: ["Plain response, no actions."])

        var gotTurn = false
        var turnText = ""
        for try await event in await session.respond(to: "Hello") {
            if case let .turn(r) = event {
                gotTurn = true
                turnText = r.content
            }
        }

        #expect(gotTurn)
        #expect(turnText == "Plain response, no actions.")
    }

    @Test func xmlSingleToolCallRoundTrip() async throws {
        // Round 1: model emits text + action block
        // Round 2: model emits final answer after seeing tool result
        let session = makeSession(
            rounds: [
                "I'll echo that.\n<action name=\"xml_echo\"><text>hello</text></action>",
                "Done. The echo returned: hello",
            ],
            tools: [XMLEchoTool()]
        )

        var toolStarted = false
        var toolResultContent = ""
        var finalText = ""

        for try await event in await session.respond(to: "Echo hello") {
            switch event {
            case let .toolCallStart(_, name):
                if name == "xml_echo" { toolStarted = true }
            case let .toolResult(_, result):
                toolResultContent = result.content
            case let .turn(r):
                finalText = r.content
            default:
                break
            }
        }

        #expect(toolStarted, "Tool should have been dispatched")
        #expect(toolResultContent == "hello", "Tool should echo the input")
        #expect(finalText == "Done. The echo returned: hello")
    }

    @Test func xmlTextBeforeActionIsEmittedAsDelta() async throws {
        let session = makeSession(
            rounds: [
                "Thinking out loud.\n<action name=\"xml_echo\"><text>x</text></action>",
                "Final",
            ],
            tools: [XMLEchoTool()]
        )

        var deltas: [String] = []
        for try await event in await session.respond(to: "Go") {
            if case let .textDelta(t) = event { deltas.append(t) }
        }

        // The text before the action block must appear as a textDelta
        let combined = deltas.joined()
        #expect(combined.contains("Thinking out loud."))
    }

    @Test func xmlToolBlockNotInTextDelta() async throws {
        let session = makeSession(
            rounds: [
                "Pre-text\n<action name=\"xml_echo\"><text>x</text></action>",
                "Final answer",
            ],
            tools: [XMLEchoTool()]
        )

        var deltas: [String] = []
        for try await event in await session.respond(to: "Go") {
            if case let .textDelta(t) = event { deltas.append(t) }
        }

        let combined = deltas.joined()
        // Action block XML should NOT appear in text deltas
        #expect(!combined.contains("<action"))
    }

    @Test func xmlNoToolsProducesPlainResponse() async throws {
        let session = makeSession(rounds: ["Just a normal reply."])

        var gotDone = false
        var text = ""
        for try await event in await session.respond(to: "Hi") {
            switch event {
            case let .turn(r): text = r.content
            case .done: gotDone = true
            default: break
            }
        }

        #expect(text == "Just a normal reply.")
        #expect(gotDone)
    }

    @Test func xmlToolDeclarationInjectedIntoSystemMessage() async throws {
        // The XML formatter should inject a tool block; verify the backend
        // receives a system message containing "Available Tools".
        var capturedSystemContent = ""
        struct CapturingBackend: ModelBackend {
            var preferredToolProtocol: ToolProtocol { .xml }
            let capture: @Sendable (String) -> Void

            func generate(
                messages: [Message],
                tools _: [ToolDefinition],
                config _: GenerationConfig
            ) -> AsyncThrowingStream<StreamChunk, Error> {
                if let sys = messages.first(where: { $0.role == .system }) {
                    capture(sys.content)
                }
                return AsyncThrowingStream { c in
                    c.yield(StreamChunk(text: "ok"))
                    c.yield(StreamChunk(finishReason: .stop))
                    c.finish()
                }
            }
        }

        let box = CaptureBox()
        let backend = CapturingBackend(capture: { box.value = $0 })
        let agent = Agent(configuration: AgentConfiguration(
            name: "A", systemPrompt: "Base.",
            tools: [XMLEchoTool()], modelId: "cap"
        ))
        let session = Session(agent: agent, backend: backend)
        for try await _ in await session.respond(to: "Hi") {}

        #expect(box.value.contains("Available Tools") || box.value.contains("xml_echo"),
                "System message should contain XML tool block")
    }
}

/// Thread-safe string box for capture in test closures.
private final class CaptureBox: @unchecked Sendable {
    var value: String = ""
}
