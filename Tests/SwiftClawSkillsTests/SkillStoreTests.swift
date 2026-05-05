import Foundation
@testable import SwiftClawSkills
import Testing

@Suite("SkillStore")
struct SkillStoreTests {
    /// Writes a minimal SKILL.md into a temp dir subdirectory and returns the temp dir URL.
    private func makeTempSkillDir(name: String = "hello", description: String = "Say hi.", body: String = "Greet by name.") throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftClawSkillTests-\(UUID().uuidString)")
        let skillDir = tmp.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let content = """
        ---
        name: \(name)
        description: \(description)
        ---
        \(body)
        """
        try content.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        return tmp
    }

    @Test func listReturnsNoBodyURL() async throws {
        let dir = try makeTempSkillDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = SkillStore(directory: dir)
        let skills = await store.list()
        #expect(skills.count == 1)
        #expect(skills[0].name == "hello")
        #expect(skills[0].description == "Say hi.")
    }

    @Test func listReturnsEmptyForMissingDirectory() async {
        let store = SkillStore(directory: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)"))
        let skills = await store.list()
        #expect(skills.isEmpty)
    }

    @Test func listCachesOnSecondCall() async throws {
        let dir = try makeTempSkillDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = SkillStore(directory: dir)
        let first = await store.list()
        // Remove the directory between calls to prove cache is used
        try FileManager.default.removeItem(at: dir)
        let second = await store.list()
        #expect(first.count == second.count)
        #expect(first[0].name == second[0].name)
    }

    @Test func loadReturnsBody() async throws {
        let dir = try makeTempSkillDir(body: "Be very polite.")
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = SkillStore(directory: dir)
        let body = try await store.load(name: "hello")
        #expect(body.contains("Be very polite."))
    }

    @Test func loadThrowsForUnknownSkill() async throws {
        let dir = try makeTempSkillDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = SkillStore(directory: dir)
        do {
            _ = try await store.load(name: "nonexistent")
            Issue.record("Expected throw for unknown skill")
        } catch let SkillError.notFound(n) {
            #expect(n == "nonexistent")
        }
    }

    @Test func listIgnoresMalformedSkills() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftClawSkillTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Good skill
        let goodDir = tmp.appendingPathComponent("good")
        try FileManager.default.createDirectory(at: goodDir, withIntermediateDirectories: true)
        try "---\nname: good\ndescription: Works.\n---\nBody.".write(to: goodDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        // Malformed skill (no frontmatter)
        let badDir = tmp.appendingPathComponent("bad")
        try FileManager.default.createDirectory(at: badDir, withIntermediateDirectories: true)
        try "Just plain text, no frontmatter.".write(to: badDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let store = SkillStore(directory: tmp)
        let skills = await store.list()
        #expect(skills.count == 1)
        #expect(skills[0].name == "good")
    }
}
