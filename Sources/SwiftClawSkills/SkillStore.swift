import Foundation

/// Loads skill metadata from disk on first access, then caches.
/// Bodies are read lazily on demand via load(name:).
public actor SkillStore {
    private let directory: URL
    private var cachedSkills: [Skill]?

    public init(directory: URL? = nil) {
        self.directory = directory ?? SkillStore.defaultDirectory()
    }

    public static func defaultDirectory() -> URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".swiftclaw/skills")
    }

    /// Returns all skill metadata (no bodies). Loads from disk on first call, then cached.
    public func list() -> [Skill] {
        if let cached = cachedSkills { return cached }
        let skills = loadAll()
        cachedSkills = skills
        return skills
    }

    /// Returns the markdown body for the named skill (strips frontmatter).
    public func load(name: String) throws -> String {
        let skills = list()
        guard let skill = skills.first(where: { $0.name == name }) else {
            throw SkillError.notFound(name)
        }
        let parsed = try SkillLoader.parse(contentsOf: skill.bodyURL)
        return parsed.body
    }

    private func loadAll() -> [Skill] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path),
              let entries = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return [] }

        var skills: [Skill] = []
        for entry in entries {
            let skillFile = entry.appendingPathComponent("SKILL.md")
            guard fm.fileExists(atPath: skillFile.path) else { continue }
            do {
                let parsed = try SkillLoader.parse(contentsOf: skillFile)
                skills.append(Skill(
                    name: parsed.name,
                    description: parsed.description,
                    triggers: parsed.triggers,
                    bodyURL: skillFile
                ))
            } catch {
                fputs("[SwiftClaw] Warning: could not parse \(skillFile.path): \(error.localizedDescription)\n", stderr)
            }
        }
        return skills.sorted { $0.name < $1.name }
    }
}
