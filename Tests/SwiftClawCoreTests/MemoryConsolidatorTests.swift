import Foundation
import Testing
@testable import SwiftClawCore

// MARK: - MemoryConsolidator Tests

@Test func consolidatorWritesValidJSON() async throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("swiftclaw-test-\(UUID().uuidString)")
    let mem = try AgentMemory(namespace: "test", baseDir: tmp)

    let jsonResponse = #"[{"key":"pref-lang","content":"User prefers Swift"}]"#
    let consolidator = MemoryConsolidator()
    let messages = [
        Message(role: .user, content: "I prefer Swift for everything"),
        Message(role: .assistant, content: "Got it, I will use Swift."),
    ]

    let keys = try await consolidator.consolidate(
        messages: messages,
        using: FixedTextBackend(text: jsonResponse),
        config: GenerationConfig(),
        into: mem,
        sessionId: "sess-1"
    )

    #expect(keys == ["pref-lang"])
    let entry = await mem.get("pref-lang")
    #expect(entry?.content == "User prefers Swift")
    #expect(entry?.source == "sess-1")
}

@Test func consolidatorFallsBackOnInvalidJSON() async throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("swiftclaw-test-\(UUID().uuidString)")
    let mem = try AgentMemory(namespace: "test", baseDir: tmp)
    let consolidator = MemoryConsolidator()
    let messages = [
        Message(role: .user, content: "Hello"),
        Message(role: .assistant, content: "Hi"),
    ]

    let keys = try await consolidator.consolidate(
        messages: messages,
        using: FixedTextBackend(text: "Not valid JSON at all"),
        config: GenerationConfig(),
        into: mem,
        sessionId: "sess-2"
    )

    // Fallback: one fact-{timestamp} key
    #expect(keys.count == 1)
    #expect(keys[0].hasPrefix("fact-"))
}

@Test func consolidatorReturnsEmptyForEmptyJSONArray() async throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("swiftclaw-test-\(UUID().uuidString)")
    let mem = try AgentMemory(namespace: "test", baseDir: tmp)
    let consolidator = MemoryConsolidator()

    let keys = try await consolidator.consolidate(
        messages: [Message(role: .user, content: "hi")],
        using: FixedTextBackend(text: "[]"),
        config: GenerationConfig(),
        into: mem,
        sessionId: "sess-3"
    )

    #expect(keys.isEmpty)
    let all = await mem.all()
    #expect(all.isEmpty)
}

@Test func consolidatorSkipsEmptyMessageList() async throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("swiftclaw-test-\(UUID().uuidString)")
    let mem = try AgentMemory(namespace: "test", baseDir: tmp)
    let consolidator = MemoryConsolidator()

    // No messages → returns [] without calling backend
    let keys = try await consolidator.consolidate(
        messages: [],
        using: FixedTextBackend(text: "[{\"key\":\"k\",\"content\":\"v\"}]"),
        config: GenerationConfig(),
        into: mem,
        sessionId: "sess-4"
    )

    #expect(keys.isEmpty)
}

// MARK: - Local mock backend (streaming protocol)

private struct FixedTextBackend: ModelBackend {
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
