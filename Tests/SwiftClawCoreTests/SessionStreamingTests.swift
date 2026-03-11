import Foundation
import Testing
@testable import SwiftClawCore

// MARK: - Multi-Chunk Mock Backend

/// A mock backend that yields an explicit sequence of StreamChunks.
struct MultiChunkBackend: ModelBackend {
    let chunks: [StreamChunk]

    func generate(
        messages: [Message],
        tools: [ToolDefinition],
        config: GenerationConfig
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        let chunks = self.chunks
        return AsyncThrowingStream { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}

// MARK: - Streaming Tests

@Test func sessionStreamingYieldsTextDeltas() async throws {
    // Backend yields 3 separate text chunks
    let backend = MultiChunkBackend(chunks: [
        StreamChunk(text: "Hello"),
        StreamChunk(text: ", "),
        StreamChunk(text: "world!"),
        StreamChunk(finishReason: .stop),
    ])

    let agent = Agent(configuration: AgentConfiguration(
        name: "Test", systemPrompt: "Test", tools: [], modelId: "mock"
    ))
    let session = Session(agent: agent, backend: backend)

    var textDeltas: [String] = []
    var turnContent = ""
    var gotDone = false

    let events = await session.respond(to: "Hi")
    for try await event in events {
        switch event {
        case let .textDelta(text):
            textDeltas.append(text)
        case let .turn(response):
            turnContent = response.content
        case .done:
            gotDone = true
        default:
            break
        }
    }

    #expect(textDeltas.count == 3)
    #expect(textDeltas[0] == "Hello")
    #expect(textDeltas[1] == ", ")
    #expect(textDeltas[2] == "world!")
    #expect(turnContent == "Hello, world!")
    #expect(gotDone)
}

@Test func sessionStreamingThinkBlock() async throws {
    // Backend yields reasoning + closing tag + real answer
    let backend = MultiChunkBackend(chunks: [
        StreamChunk(text: "reasoning content</think>answer text"),
        StreamChunk(finishReason: .stop),
    ])

    let agent = Agent(configuration: AgentConfiguration(
        name: "Test", systemPrompt: "Test", tools: [], modelId: "mock"
    ))
    let session = Session(agent: agent, backend: backend)

    var thinkingDeltas: [String] = []
    var textDeltas: [String] = []
    var turnContent = ""

    let events = await session.respond(to: "Hi")
    for try await event in events {
        switch event {
        case let .thinkingDelta(text):
            thinkingDeltas.append(text)
        case let .textDelta(text):
            textDeltas.append(text)
        case let .turn(response):
            turnContent = response.content
        default:
            break
        }
    }

    #expect(!thinkingDeltas.isEmpty)
    #expect(thinkingDeltas.joined() == "reasoning content")
    #expect(!textDeltas.isEmpty)
    #expect(textDeltas.joined() == "answer text")
    #expect(turnContent == "answer text")
}

@Test func sessionStreamingNoThink() async throws {
    // Backend yields normal text with no think block
    let backend = MultiChunkBackend(chunks: [
        StreamChunk(text: "Simple "),
        StreamChunk(text: "answer"),
        StreamChunk(finishReason: .stop),
    ])

    let agent = Agent(configuration: AgentConfiguration(
        name: "Test", systemPrompt: "Test", tools: [], modelId: "mock"
    ))
    let session = Session(agent: agent, backend: backend)

    var thinkingDeltas: [String] = []
    var textDeltas: [String] = []
    var turnContent = ""

    let events = await session.respond(to: "Hi")
    for try await event in events {
        switch event {
        case let .thinkingDelta(text):
            thinkingDeltas.append(text)
        case let .textDelta(text):
            textDeltas.append(text)
        case let .turn(response):
            turnContent = response.content
        default:
            break
        }
    }

    #expect(thinkingDeltas.isEmpty)
    #expect(textDeltas == ["Simple ", "answer"])
    #expect(turnContent == "Simple answer")
}
