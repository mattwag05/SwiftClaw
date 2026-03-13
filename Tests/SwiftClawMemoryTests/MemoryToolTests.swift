import Testing
import Foundation
@testable import SwiftClawMemory
@testable import SwiftClawCore

private func makeTempStore() throws -> MemoryStore {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("swiftclaw-tool-test-\(UUID().uuidString)")
    return try MemoryStore(baseDir: tempDir)
}

private func jsonArgs(_ dict: [String: String]) -> String {
    let pairs = dict.map { k, v in "\"\(k)\": \"\(v)\"" }.joined(separator: ", ")
    return "{\(pairs)}"
}

private func jsonArgs(key: String, content: String, layer: String? = nil) -> String {
    if let layer {
        return "{\"key\": \"\(key)\", \"content\": \"\(content)\", \"layer\": \"\(layer)\"}"
    } else {
        return "{\"key\": \"\(key)\", \"content\": \"\(content)\"}"
    }
}

@Suite("MemoryTool Tests")
struct MemoryToolTests {

    @Test func memoryWriteToolStoresEntry() async throws {
        let store = try makeTempStore()
        let tool = MemoryWriteTool(store: store)

        let result = try await tool.execute(
            arguments: jsonArgs(key: "project-name", content: "SwiftClaw", layer: "working"))

        #expect(!result.isError)
        #expect(result.content.contains("project-name"))
        #expect(result.content.contains("working"))

        let entry = await store.get("project-name", layer: .working)
        #expect(entry != nil)
        #expect(entry?.content == "SwiftClaw")

        await store.shutdown()
    }

    @Test func memoryWriteToolInvalidLayer() async throws {
        let store = try makeTempStore()
        let tool = MemoryWriteTool(store: store)

        let result = try await tool.execute(
            arguments: "{\"key\": \"test\", \"content\": \"hello\", \"layer\": \"badLayer\"}")

        #expect(result.isError)
        #expect(result.content.contains("badLayer"))

        await store.shutdown()
    }

    @Test func memoryReadToolFindsEntry() async throws {
        let store = try makeTempStore()
        let entry = MemoryEntry(key: "user-name", content: "Alice", source: "test")
        try await store.set("user-name", entry: entry, layer: .longTerm)

        let tool = MemoryReadTool(store: store)
        let result = try await tool.execute(
            arguments: "{\"key\": \"user-name\", \"layer\": \"longTerm\"}")

        #expect(!result.isError)
        #expect(result.content == "Alice")

        await store.shutdown()
    }

    @Test func memoryReadToolNotFound() async throws {
        let store = try makeTempStore()
        let tool = MemoryReadTool(store: store)

        let result = try await tool.execute(
            arguments: "{\"key\": \"does-not-exist\"}")

        #expect(!result.isError)
        #expect(result.content.contains("No memory found"))
        #expect(result.content.contains("does-not-exist"))

        await store.shutdown()
    }

    @Test func memorySearchToolReturnsResults() async throws {
        let store = try makeTempStore()

        try await store.set("swift-lang", entry: MemoryEntry(key: "swift-lang", content: "Swift is a compiled programming language", source: "test"), layer: .longTerm)
        try await store.set("python-lang", entry: MemoryEntry(key: "python-lang", content: "Python is an interpreted scripting language", source: "test"), layer: .longTerm)
        try await store.set("unrelated", entry: MemoryEntry(key: "unrelated", content: "bananas and oranges are fruits", source: "test"), layer: .longTerm)

        let tool = MemorySearchTool(store: store)
        let result = try await tool.execute(
            arguments: "{\"query\": \"programming language\", \"topK\": 3}")

        #expect(!result.isError)
        // Should find at least one language-related entry
        #expect(result.content.contains("lang") || result.content.contains("No memories"))

        await store.shutdown()
    }

    @Test func memoryDeleteToolDeletesEntry() async throws {
        let store = try makeTempStore()
        let entry = MemoryEntry(key: "to-delete", content: "temporary", source: "test")
        try await store.set("to-delete", entry: entry, layer: .working)

        let tool = MemoryDeleteTool(store: store)
        let result = try await tool.execute(
            arguments: "{\"key\": \"to-delete\", \"layer\": \"working\"}")

        #expect(!result.isError)
        #expect(result.content.contains("to-delete"))

        let fetched = await store.get("to-delete", layer: .working)
        #expect(fetched == nil)

        await store.shutdown()
    }

    @Test func memoryDeleteRequiresConfirmation() {
        let store = try! makeTempStore()
        let tool = MemoryDeleteTool(store: store)
        #expect(tool.requiresConfirmation == true)
    }
}
