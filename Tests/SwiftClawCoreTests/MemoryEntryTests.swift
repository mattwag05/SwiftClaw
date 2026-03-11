import Foundation
import Testing
@testable import SwiftClawCore

// MARK: - MemoryEntry Tests

@Test func memoryEntryCodableRoundTrip() throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let entry = MemoryEntry(
        key: "pref-editor",
        content: "User prefers Neovim",
        updatedAt: Date(timeIntervalSince1970: 1_000_000),
        source: "session-abc"
    )
    let data = try encoder.encode(entry)
    let decoded = try decoder.decode(MemoryEntry.self, from: data)
    #expect(decoded.key == entry.key)
    #expect(decoded.content == entry.content)
    #expect(decoded.source == entry.source)
}

@Test func agentMemorySetAndGet() async throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("swiftclaw-test-\(UUID().uuidString)")
    let mem = try AgentMemory(namespace: "test", baseDir: tmp)
    let entry = MemoryEntry(key: "foo", content: "bar", source: "sess-1")
    try await mem.set("foo", entry: entry)
    let got = await mem.get("foo")
    #expect(got?.content == "bar")
    #expect(got?.source == "sess-1")
}

@Test func agentMemoryFormatted() async throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("swiftclaw-test-\(UUID().uuidString)")
    let mem = try AgentMemory(namespace: "test", baseDir: tmp)
    try await mem.set("alpha", entry: MemoryEntry(key: "alpha", content: "first", source: "s"))
    try await mem.set("beta", entry: MemoryEntry(key: "beta", content: "second", source: "s"))
    let formatted = await mem.formatted()
    #expect(formatted.contains("- alpha: first"))
    #expect(formatted.contains("- beta: second"))
}

@Test func agentMemoryDelete() async throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("swiftclaw-test-\(UUID().uuidString)")
    let mem = try AgentMemory(namespace: "test", baseDir: tmp)
    let entry = MemoryEntry(key: "k", content: "v", source: "s")
    try await mem.set("k", entry: entry)
    try await mem.delete("k")
    let got = await mem.get("k")
    #expect(got == nil)
}

@Test func agentMemoryLegacyMigration() async throws {
    // Write a legacy [String: String] file and verify migration on load
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("swiftclaw-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: tmp.appendingPathComponent("memory"),
        withIntermediateDirectories: true
    )
    let legacyFile = tmp.appendingPathComponent("memory/legacy-ns.json")
    let legacyData = try JSONEncoder().encode(["mykey": "myvalue"])
    try legacyData.write(to: legacyFile)

    let mem = try AgentMemory(namespace: "legacy-ns", baseDir: tmp)
    let entry = await mem.get("mykey")
    #expect(entry?.content == "myvalue")
    #expect(entry?.source == "migrated")
}
