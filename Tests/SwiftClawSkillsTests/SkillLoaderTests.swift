import Foundation
@testable import SwiftClawSkills
import Testing

@Suite("SkillLoader")
struct SkillLoaderTests {
    @Test func parsesValidFrontmatter() throws {
        let text = """
        ---
        name: greet
        description: Say hello.
        triggers: [hi, hello, greet]
        ---
        Always say hello by name.
        """
        let result = try SkillLoader.parse(text: text)
        #expect(result.name == "greet")
        #expect(result.description == "Say hello.")
        #expect(result.triggers == ["hi", "hello", "greet"])
        #expect(result.body.contains("Always say hello"))
    }

    @Test func parsesNoTriggers() throws {
        let text = """
        ---
        name: docs
        description: Write documentation.
        ---
        Write clear docs.
        """
        let result = try SkillLoader.parse(text: text)
        #expect(result.triggers.isEmpty)
        #expect(result.body.contains("Write clear docs"))
    }

    @Test func throwsOnMissingFrontmatter() {
        let text = "Just a plain markdown file.\nNo frontmatter."
        #expect(throws: SkillError.missingFrontmatter) {
            try SkillLoader.parse(text: text)
        }
    }

    @Test func throwsOnMissingName() {
        let text = """
        ---
        description: Some skill.
        ---
        Body here.
        """
        #expect(throws: SkillError.missingField("name")) {
            try SkillLoader.parse(text: text)
        }
    }

    @Test func throwsOnMissingDescription() {
        let text = """
        ---
        name: foo
        ---
        Body here.
        """
        #expect(throws: SkillError.missingField("description")) {
            try SkillLoader.parse(text: text)
        }
    }

    @Test func throwsOnUnclosedFence() {
        let text = """
        ---
        name: incomplete
        description: Missing closing fence.
        """
        #expect(throws: SkillError.missingFrontmatter) {
            try SkillLoader.parse(text: text)
        }
    }

    @Test func stripsLeadingNewlineFromBody() throws {
        let text = "---\nname: n\ndescription: d\n---\nBody."
        let result = try SkillLoader.parse(text: text)
        #expect(!result.body.hasPrefix("\n"))
        #expect(result.body == "Body.")
    }

    @Test func parseListHandlesBracketed() {
        let parsed = SkillLoader.parseList("[a, b, c]")
        #expect(parsed == ["a", "b", "c"])
    }

    @Test func parseListHandlesBare() {
        let parsed = SkillLoader.parseList("single")
        #expect(parsed == ["single"])
    }

    @Test func parseListHandlesEmpty() {
        let parsed = SkillLoader.parseList("[]")
        #expect(parsed.isEmpty)
    }
}
