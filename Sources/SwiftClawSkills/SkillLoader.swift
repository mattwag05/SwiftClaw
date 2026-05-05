import Foundation

/// Parses agentskills.io-style YAML frontmatter + markdown body from a SKILL.md file.
public enum SkillLoader {
    public struct ParsedSkill {
        public let name: String
        public let description: String
        public let triggers: [String]
        public let body: String
    }

    public static func parse(contentsOf url: URL) throws -> ParsedSkill {
        let text = try String(contentsOf: url, encoding: .utf8)
        return try parse(text: text)
    }

    public static func parse(text rawText: String) throws -> ParsedSkill {
        // Strip UTF-8 BOM if present
        let text = rawText.hasPrefix("\u{feff}") ? String(rawText.dropFirst()) : rawText

        guard text.hasPrefix("---") else {
            throw SkillError.missingFrontmatter
        }

        let lines = text.components(separatedBy: "\n")

        var closingIndex: Int?
        for i in 1 ..< lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                closingIndex = i
                break
            }
        }
        guard let closing = closingIndex else {
            throw SkillError.missingFrontmatter
        }

        var fields: [String: String] = [:]
        var triggers: [String] = []
        for line in lines[1 ..< closing] {
            guard let colonRange = line.range(of: ": ") ?? (line.hasSuffix(":") ? line.range(of: ":") : nil) else {
                continue
            }
            let key = String(line[line.startIndex ..< colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let value = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if key == "triggers" {
                triggers = parseList(value)
            } else {
                fields[key] = value
            }
        }

        guard let name = fields["name"], !name.isEmpty else {
            throw SkillError.missingField("name")
        }
        guard let description = fields["description"], !description.isEmpty else {
            throw SkillError.missingField("description")
        }

        let bodyLines = Array(lines[(closing + 1)...])
        var body = bodyLines.joined(separator: "\n")
        if body.hasPrefix("\n") { body = String(body.dropFirst()) }

        return ParsedSkill(name: name, description: description, triggers: triggers, body: body)
    }

    /// Parses [a, b, c] or bare value into a [String] array.
    static func parseList(_ value: String) -> [String] {
        let v = value.trimmingCharacters(in: .whitespaces)
        if v.hasPrefix("["), v.hasSuffix("]") {
            let inner = String(v.dropFirst().dropLast())
            return inner.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
                .filter { !$0.isEmpty }
        }
        return v.isEmpty ? [] : [v]
    }
}
