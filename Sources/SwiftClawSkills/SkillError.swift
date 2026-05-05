import Foundation

public enum SkillError: LocalizedError, Equatable {
    case missingFrontmatter
    case missingField(String)
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .missingFrontmatter:
            return "SKILL.md must start with a --- YAML frontmatter block"
        case let .missingField(field):
            return "SKILL.md is missing required field: \(field)"
        case let .notFound(name):
            return "Skill not found: \(name)"
        }
    }
}
