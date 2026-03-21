import Foundation
import Testing
@testable import SwiftClawCore

// MARK: - Mock MemoryProvider

private actor MockMemoryProvider: MemoryProvider {
    var store: [String: MemoryEntry] = [:]

    func get(_ key: String, layer: MemoryLayer?) async -> MemoryEntry? {
        store[key]
    }
    func set(_ key: String, entry: MemoryEntry, layer: MemoryLayer) async throws {
        store[key] = entry
    }
    func delete(_ key: String, layer: MemoryLayer) async throws {
        store.removeValue(forKey: key)
    }
    func search(query: String, layer: MemoryLayer?, topK: Int) async throws -> [ScoredMemory] { [] }
    func promote(keys: [String]) async throws {}
    func allEntries(layer: MemoryLayer?) async -> [MemoryEntry] { Array(store.values) }
    func clearLayer(_ layer: MemoryLayer) async throws { store = [:] }
    func shutdown() async {}
}

// MARK: - MemoryConsolidator Tests

@Test func consolidatorWritesValidJSON() async throws {
    let mem = MockMemoryProvider()

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
        layer: .working,
        sessionId: "sess-1"
    )

    #expect(keys == ["pref-lang"])
    let entry = await mem.get("pref-lang", layer: nil)
    #expect(entry?.content == "User prefers Swift")
    #expect(entry?.source == "sess-1")
}

@Test func consolidatorDropsSilentlyOnInvalidJSON() async throws {
    let mem = MockMemoryProvider()
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
        layer: .working,
        sessionId: "sess-2"
    )

    // Malformed LLM responses are silently dropped — no garbage facts stored.
    #expect(keys.isEmpty)
    let all = await mem.allEntries(layer: nil)
    #expect(all.isEmpty)
}

@Test func consolidatorReturnsEmptyForEmptyJSONArray() async throws {
    let mem = MockMemoryProvider()
    let consolidator = MemoryConsolidator()

    let keys = try await consolidator.consolidate(
        messages: [Message(role: .user, content: "hi")],
        using: FixedTextBackend(text: "[]"),
        config: GenerationConfig(),
        into: mem,
        layer: .working,
        sessionId: "sess-3"
    )

    #expect(keys.isEmpty)
    let all = await mem.allEntries(layer: nil)
    #expect(all.isEmpty)
}

@Test func consolidatorSkipsEmptyMessageList() async throws {
    let mem = MockMemoryProvider()
    let consolidator = MemoryConsolidator()

    // No messages → returns [] without calling backend
    let keys = try await consolidator.consolidate(
        messages: [],
        using: FixedTextBackend(text: "[{\"key\":\"k\",\"content\":\"v\"}]"),
        config: GenerationConfig(),
        into: mem,
        layer: .working,
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
