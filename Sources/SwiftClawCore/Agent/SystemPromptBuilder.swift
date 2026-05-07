import Foundation

/// Composes the final system prompt for a session from multiple sources:
/// mode-default prompt, per-session override, Skills, and tool-protocol prose.
public struct SystemPromptBuilder: Sendable {
    public let mode: SessionMode
    public let workspacePath: String?
    public let sessionId: String?
    public let override: String?
    public let skillsSection: String?

    public init(
        mode: SessionMode,
        workspacePath: String? = nil,
        sessionId: String? = nil,
        override: String? = nil,
        skillsSection: String? = nil
    ) {
        self.mode = mode
        self.workspacePath = workspacePath
        self.sessionId = sessionId
        self.override = override
        self.skillsSection = skillsSection
    }

    /// Build the final system prompt string.
    public func build(enableTools: Bool = true) -> String {
        // 1. Mode-default base prompt
        var prompt: String
        if mode == .build, let wp = workspacePath, let sid = sessionId {
            let previewHref = "swiftclaw-workspace://\(sid)/"
            prompt = BuildSystemPrompt.build(workspacePath: wp, previewHref: previewHref)
        } else if mode == .build {
            // Build mode but workspace not created yet — use chat prompt as fallback
            prompt = ChatSystemPrompt.build(enableTools: enableTools)
        } else {
            prompt = ChatSystemPrompt.build(enableTools: enableTools)
        }

        // 2. Per-session override replaces the base entirely when present
        if let ov = override, !ov.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt = ov
        }

        // 3. Skills section appended at the end
        if let section = skillsSection {
            prompt += "\n\n" + section
        }

        return prompt
    }
}
