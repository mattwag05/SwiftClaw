import Foundation

/// A skill definition — metadata only (no body in memory until `skill_load` is called).
public struct Skill: Sendable, Equatable {
    public let name: String
    public let description: String
    public let triggers: [String]
    /// URL of the SKILL.md file; body is read on demand via SkillStore.load(name:).
    public let bodyURL: URL

    public init(name: String, description: String, triggers: [String] = [], bodyURL: URL) {
        self.name = name
        self.description = description
        self.triggers = triggers
        self.bodyURL = bodyURL
    }
}
