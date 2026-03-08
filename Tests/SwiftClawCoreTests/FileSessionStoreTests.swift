import Foundation
import Testing
@testable import SwiftClawCore

@Suite("FileSessionStore")
struct FileSessionStoreTests {

    /// Creates a temporary directory, runs the closure, then cleans up.
    private func withTempStore(_ body: (FileSessionStore) async throws -> Void) async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftclaw-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try FileSessionStore(baseDir: dir)
        try await body(store)
    }

    private func makeMessages() -> [Message] {
        [
            Message(role: .system, content: "You are a test agent."),
            Message(role: .user, content: "Hello"),
            Message(role: .assistant, content: "Hi there!"),
        ]
    }

    private func makeMetadata() -> SessionMetadata {
        SessionMetadata(agentName: "TestAgent", modelId: "test-model")
    }

    @Test("Save and load round-trip preserves messages")
    func saveLoadRoundTrip() async throws {
        try await withTempStore { store in
            let messages = makeMessages()
            let metadata = makeMetadata()
            try await store.save(sessionId: "test-session", messages: messages, metadata: metadata)
            let loaded = try await store.load(sessionId: "test-session")
            #expect(loaded.messages.count == messages.count)
            #expect(loaded.messages[0].role == .system)
            #expect(loaded.messages[1].content == "Hello")
            #expect(loaded.metadata.agentName == "TestAgent")
        }
    }

    @Test("List returns saved sessions sorted by date descending")
    func listReturnsSortedSessions() async throws {
        try await withTempStore { store in
            let earlier = Date(timeIntervalSinceReferenceDate: 1_000_000)
            let later   = Date(timeIntervalSinceReferenceDate: 2_000_000)
            let metaA = SessionMetadata(agentName: "Agent", modelId: "m", updatedAt: earlier)
            let metaB = SessionMetadata(agentName: "Agent", modelId: "m", updatedAt: later)
            try await store.save(sessionId: "session-a", messages: makeMessages(), metadata: metaA)
            try await store.save(sessionId: "session-b", messages: makeMessages(), metadata: metaB)

            let list = try await store.list()
            #expect(list.count == 2)
            // Most recently updated should be first
            #expect(list[0].sessionId == "session-b")
            #expect(list[1].sessionId == "session-a")
        }
    }

    @Test("Delete removes session from store")
    func deleteRemovesSession() async throws {
        try await withTempStore { store in
            try await store.save(sessionId: "to-delete", messages: makeMessages(), metadata: makeMetadata())
            try await store.delete(sessionId: "to-delete")
            let list = try await store.list()
            #expect(list.isEmpty)
        }
    }

    @Test("Load non-existent session throws sessionNotFound")
    func loadNonExistentThrows() async throws {
        try await withTempStore { store in
            await #expect(throws: SwiftClawError.sessionNotFound("ghost")) {
                _ = try await store.load(sessionId: "ghost")
            }
        }
    }

    @Test("Delete non-existent session throws sessionNotFound")
    func deleteNonExistentThrows() async throws {
        try await withTempStore { store in
            await #expect(throws: SwiftClawError.sessionNotFound("ghost")) {
                try await store.delete(sessionId: "ghost")
            }
        }
    }

    @Test("Invalid session ID containing slash throws storageError")
    func invalidSessionIdSlashThrows() async throws {
        try await withTempStore { store in
            await #expect(throws: SwiftClawError.storageError("Invalid session ID")) {
                try await store.save(sessionId: "../evil", messages: [], metadata: makeMetadata())
            }
        }
    }

    @Test("Invalid session ID containing path traversal throws storageError")
    func invalidSessionIdPathTraversalThrows() async throws {
        try await withTempStore { store in
            await #expect(throws: SwiftClawError.storageError("Invalid session ID")) {
                _ = try await store.load(sessionId: "../../etc/passwd")
            }
        }
    }

    @Test("Invalid session ID exceeding 100 chars throws storageError")
    func invalidSessionIdTooLongThrows() async throws {
        try await withTempStore { store in
            let longId = String(repeating: "a", count: 101)
            await #expect(throws: SwiftClawError.storageError("Invalid session ID")) {
                try await store.delete(sessionId: longId)
            }
        }
    }
}
