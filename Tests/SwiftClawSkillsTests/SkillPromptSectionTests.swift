import Foundation
@testable import SwiftClawSkills
import Testing

@Suite("SkillPromptSection")
struct SkillPromptSectionTests {
    @Test func returnsNilForEmptyList() {
        #expect(SkillPromptSection.build(skills: []) == nil)
    }

    @Test func includesAllSkillNames() throws {
        let skills = [
            Skill(name: "alpha", description: "First skill.", bodyURL: URL(fileURLWithPath: "/tmp/a")),
            Skill(name: "beta", description: "Second skill.", bodyURL: URL(fileURLWithPath: "/tmp/b")),
        ]
        let section = try #require(SkillPromptSection.build(skills: skills))
        #expect(section.contains("alpha"))
        #expect(section.contains("First skill."))
        #expect(section.contains("beta"))
        #expect(section.contains("Second skill."))
    }

    @Test func includesSkillLoadInstruction() throws {
        let skills = [Skill(name: "x", description: "X skill.", bodyURL: URL(fileURLWithPath: "/tmp/x"))]
        let section = try #require(SkillPromptSection.build(skills: skills))
        #expect(section.contains("skill_load"))
    }

    @Test func sectionAppendsCleanlyToBasePrompt() throws {
        let base = "You are an assistant."
        let skills = [Skill(name: "greet", description: "Greet users.", bodyURL: URL(fileURLWithPath: "/tmp/g"))]
        let section = try #require(SkillPromptSection.build(skills: skills))
        let combined = base + section
        #expect(combined.hasPrefix("You are an assistant."))
        #expect(combined.contains("## Available Skills"))
    }
}
