/// Builds the ## Available Skills system-prompt section from a list of skills.
public enum SkillPromptSection {
    /// Returns a formatted prompt appendix listing skill names and descriptions,
    /// or nil if the list is empty.
    public static func build(skills: [Skill]) -> String? {
        guard !skills.isEmpty else { return nil }
        let lines = skills.map { "- **\($0.name)**: \($0.description)" }.joined(separator: "\n")
        return """

        ## Available Skills
        \(lines)
        Use the `skill_load` tool to fetch full instructions for a skill before using it.
        """
    }
}
