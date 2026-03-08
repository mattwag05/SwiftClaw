import Foundation
import Testing
@testable import SwiftClawCore

/// A backend that yields predefined text chunks and a finish reason.
private struct ChunkBackend: ModelBackend {
    let chunks: [String]
    let finishReason: StreamChunk.FinishReason

    func generate(
        messages: [Message],
        tools: [ToolDefinition],
        config: GenerationConfig
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            for chunk in chunks {
                continuation.yield(StreamChunk(text: chunk))
            }
            continuation.yield(StreamChunk(finishReason: finishReason))
            continuation.finish()
        }
    }
}

@Suite("ModelBackend think-stripping and tool-call cleaning")
struct ModelBackendTests {

    private func generate(text: String) async throws -> GenerationResponse {
        let backend = ChunkBackend(chunks: [text], finishReason: .stop)
        return try await backend.generate(
            messages: [],
            tools: [],
            config: GenerationConfig()
        )
    }

    @Test("Think block closed with </think> strips everything before it")
    func thinkBlockStripped() async throws {
        let response = try await generate(text: "reasoning here</think>\nActual answer")
        #expect(response.content == "Actual answer")
    }

    @Test("Unclosed <think> block strips from tag to end")
    func unclosedThinkBlockStripped() async throws {
        let response = try await generate(text: "Preamble<think>thinking never ends")
        #expect(response.content == "Preamble")
    }

    @Test("tool_call XML block is stripped from text")
    func toolCallXmlStripped() async throws {
        let input = "Some text\n<tool_call>\n<function=foo></function>\n</tool_call>\nAfter"
        let response = try await generate(text: input)
        #expect(!response.content.contains("<tool_call>"))
        #expect(!response.content.contains("</tool_call>"))
        #expect(response.content.contains("Some text"))
        #expect(response.content.contains("After"))
    }

    @Test("Bare function block is stripped from text")
    func bareFunctionBlockStripped() async throws {
        let input = "Before\n<function=date_time>\n</function>\nAfter"
        let response = try await generate(text: input)
        #expect(!response.content.contains("<function="))
        #expect(!response.content.contains("</function>"))
        #expect(response.content.contains("Before"))
        #expect(response.content.contains("After"))
    }

    @Test("Plain text passes through unchanged")
    func plainTextUnchanged() async throws {
        let response = try await generate(text: "Hello, world!")
        #expect(response.content == "Hello, world!")
    }

    @Test("Text with both think and tool call blocks is fully cleaned")
    func thinkAndToolCallCleaned() async throws {
        let input = "reasoning</think>\n<function=shell>\n<parameter=command>ls</parameter>\n</function>\nDone"
        let response = try await generate(text: input)
        #expect(!response.content.contains("</think>"))
        #expect(!response.content.contains("<function="))
        #expect(response.content.contains("Done"))
    }
}
