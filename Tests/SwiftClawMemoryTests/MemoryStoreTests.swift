import Testing
import Foundation
@testable import SwiftClawMemory
@testable import SwiftClawCore

private func makeTempStore() throws -> MemoryStore {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("swiftclaw-test-\(UUID().uuidString)")
    return try MemoryStore(baseDir: tempDir)
}

@Suite("MemoryStore Tests")
struct MemoryStoreTests {

    @Test func memoryStoreCRUDWorkingLayer() async throws {
        let store = try makeTempStore()
        let entry = MemoryEntry(key: "test-key", content: "hello working", source: "test")

        try await store.set("test-key", entry: entry, layer: .working)

        let fetched = await store.get("test-key", layer: .working)
        #expect(fetched != nil)
        #expect(fetched?.content == "hello working")

        try await store.delete("test-key", layer: .working)

        let deleted = await store.get("test-key", layer: .working)
        #expect(deleted == nil)

        await store.shutdown()
    }

    @Test func memoryStoreCRUDLongTermLayer() async throws {
        let store = try makeTempStore()
        let entry = MemoryEntry(key: "lt-key", content: "long term content", source: "test")

        try await store.set("lt-key", entry: entry, layer: .longTerm)

        let fetched = await store.get("lt-key", layer: .longTerm)
        #expect(fetched != nil)
        #expect(fetched?.content == "long term content")

        try await store.delete("lt-key", layer: .longTerm)

        let deleted = await store.get("lt-key", layer: .longTerm)
        #expect(deleted == nil)

        await store.shutdown()
    }

    @Test func memoryStoreGetNilLayerSearchesBothWorkingFirst() async throws {
        let store = try makeTempStore()
        let workingEntry = MemoryEntry(key: "shared-key", content: "from working", source: "test")
        let longTermEntry = MemoryEntry(key: "shared-key", content: "from longTerm", source: "test")

        try await store.set("shared-key", entry: workingEntry, layer: .working)
        try await store.set("shared-key", entry: longTermEntry, layer: .longTerm)

        let fetched = await store.get("shared-key", layer: nil)
        #expect(fetched != nil)
        #expect(fetched?.content == "from working")

        await store.shutdown()
    }

    @Test func memoryStorePromoteMovesProperly() async throws {
        let store = try makeTempStore()
        let entry = MemoryEntry(key: "promote-key", content: "to be promoted", source: "test")

        try await store.set("promote-key", entry: entry, layer: .working)
        try await store.promote(keys: ["promote-key"])

        let inLongTerm = await store.get("promote-key", layer: .longTerm)
        #expect(inLongTerm != nil)
        #expect(inLongTerm?.content == "to be promoted")

        let inWorking = await store.get("promote-key", layer: .working)
        #expect(inWorking == nil)

        await store.shutdown()
    }

    @Test func memoryStorePromoteOverwritesExisting() async throws {
        let store = try makeTempStore()
        let workingEntry = MemoryEntry(key: "overwrite-key", content: "new content from working", source: "test")
        let existingLongTerm = MemoryEntry(key: "overwrite-key", content: "old longterm content", source: "old-session")

        try await store.set("overwrite-key", entry: existingLongTerm, layer: .longTerm)
        try await store.set("overwrite-key", entry: workingEntry, layer: .working)
        try await store.promote(keys: ["overwrite-key"])

        let inLongTerm = await store.get("overwrite-key", layer: .longTerm)
        #expect(inLongTerm != nil)
        #expect(inLongTerm?.content == "new content from working")

        let inWorking = await store.get("overwrite-key", layer: .working)
        #expect(inWorking == nil)

        await store.shutdown()
    }

    @Test func memoryStoreClearLayerOnlyAffectsTargetLayer() async throws {
        let store = try makeTempStore()

        try await store.set("w1", entry: MemoryEntry(key: "w1", content: "working 1", source: "test"), layer: .working)
        try await store.set("w2", entry: MemoryEntry(key: "w2", content: "working 2", source: "test"), layer: .working)
        try await store.set("lt1", entry: MemoryEntry(key: "lt1", content: "long term 1", source: "test"), layer: .longTerm)

        try await store.clearLayer(.working)

        let workingEntries = await store.allEntries(layer: .working)
        #expect(workingEntries.isEmpty)

        let longTermEntries = await store.allEntries(layer: .longTerm)
        #expect(longTermEntries.count == 1)
        #expect(longTermEntries.first?.key == "lt1")

        await store.shutdown()
    }

    @Test func memoryStoreJSONMigration() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftclaw-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Write a legacy JSON file
        let legacyEntry = MemoryEntry(key: "migrated-key", content: "migrated content", source: "migrated")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let dict: [String: MemoryEntry] = ["migrated-key": legacyEntry]
        let data = try encoder.encode(dict)
        let jsonFile = tempDir.appendingPathComponent("legacy.json")
        try data.write(to: jsonFile)

        let store = try MemoryStore(baseDir: tempDir)

        // Verify import
        let fetched = await store.get("migrated-key", layer: .longTerm)
        #expect(fetched != nil)
        #expect(fetched?.content == "migrated content")

        // Verify file was renamed
        let migratedFile = tempDir.appendingPathComponent("legacy.json.migrated")
        #expect(FileManager.default.fileExists(atPath: migratedFile.path))
        #expect(!FileManager.default.fileExists(atPath: jsonFile.path))

        await store.shutdown()
    }

    @Test func memoryStoreFTSSearch() async throws {
        let store = try makeTempStore()

        try await store.set("alpha", entry: MemoryEntry(key: "alpha", content: "the quick brown fox", source: "test"), layer: .longTerm)
        try await store.set("beta", entry: MemoryEntry(key: "beta", content: "jumps over the lazy dog", source: "test"), layer: .longTerm)
        try await store.set("gamma", entry: MemoryEntry(key: "gamma", content: "swift programming language features", source: "test"), layer: .longTerm)

        let results = try await store.search(query: "swift", layer: nil, topK: 5)
        #expect(!results.isEmpty)
        #expect(results.first?.entry.key == "gamma")

        await store.shutdown()
    }
}
