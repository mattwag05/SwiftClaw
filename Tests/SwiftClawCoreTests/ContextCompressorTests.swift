import Foundation
import Testing
@testable import SwiftClawCore

// MARK: - ContextCompressor Tests

@Test func tokenEstimation() {
    let compressor = ContextCompressor()
    let messages = [
        Message(role: .user, content: "Hello world"),   // 11 chars → ~2 tokens
        Message(role: .assistant, content: "Hi there!"), // 9 chars → ~2 tokens
    ]
    let estimate = compressor.estimateTokens(messages)
    #expect(estimate >= 4)
}

@Test func compressorPassthroughWhenTooFewMessages() async throws {
    let compressor = ContextCompressor()
    let messages = [
        Message(role: .system, content: "System"),
        Message(role: .user, content: "A"),
        Message(role: .assistant, content: "B"),
    ]
    // keepRecent = 3, only 3 messages total → no compressible region
    let result = try await compressor.compress(
        messages,
        using: FixedResponseBackend(text: "Summary here"),
        config: GenerationConfig(),
        keepRecent: 3
    )
    #expect(result.count == messages.count)
    #expect(result[0].content == "System")
}

@Test func compressorInjectsSummaryMessage() async throws {
    let compressor = ContextCompressor()
    var messages: [Message] = [Message(role: .system, content: "System")]
    for i in 0..<8 {
        messages.append(Message(role: .user, content: "User turn \(i)"))
        messages.append(Message(role: .assistant, content: "Assistant turn \(i)"))
    }
    // keepRecent = 4 → [system] + [12 compressible] + [4 kept] = 17 total
    let result = try await compressor.compress(
        messages,
        using: FixedResponseBackend(text: "Compact summary"),
        config: GenerationConfig(),
        keepRecent: 4
    )
    // Result: [system, recap] + 4 recent = 6
    #expect(result.count == 6)
    #expect(result[0].role == MessageRole.system)
    #expect(result[1].role == MessageRole.system)
    #expect(result[1].content.hasPrefix("## Prior Context"))
    #expect(result[1].content.contains("Compact summary"))
}

@Test func compressorKeepsSystemMessageIntact() async throws {
    let compressor = ContextCompressor()
    let systemContent = "You are the best assistant."
    var messages: [Message] = [Message(role: .system, content: systemContent)]
    for i in 0..<6 {
        messages.append(Message(role: .user, content: "q\(i)"))
        messages.append(Message(role: .assistant, content: "a\(i)"))
    }
    let result = try await compressor.compress(
        messages,
        using: FixedResponseBackend(text: "ok"),
        config: GenerationConfig(),
        keepRecent: 4
    )
    #expect(result[0].content == systemContent)
}

// MARK: - Local mock backend (streaming protocol)

private struct FixedResponseBackend: ModelBackend {
    let text: String

    func generate(
        messages: [Message],
        tools: [ToolDefinition],
        config: GenerationConfig
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        let t = text
        return AsyncThrowingStream { continuation in
            continuation.yield(StreamChunk(text: t))
            continuation.yield(StreamChunk(finishReason: .stop))
            continuation.finish()
        }
    }
}
