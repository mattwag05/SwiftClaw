/// Composes the final system prompt for a session from multiple sources:
/// mode-default prompt, per-session override, and Skills.
public struct SystemPromptBuilder: Sendable {
    public let mode: SessionMode
    public let workspacePath: String?
    public let sessionId: String?
    public let systemPromptOverride: String?

    public init(
        mode: SessionMode,
        workspacePath: String? = nil,
        sessionId: String? = nil,
        systemPromptOverride: String? = nil
    ) {
        self.mode = mode
        self.workspacePath = workspacePath
        self.sessionId = sessionId
        self.systemPromptOverride = systemPromptOverride
    }

    public func build(enableTools: Bool = true) -> String {
        var prompt: String
        if mode == .build, let wp = workspacePath, let sid = sessionId {
            prompt = BuildSystemPrompt.build(
                workspacePath: wp,
                previewHref: "swiftclaw-workspace://\(sid)/"
            )
        } else {
            prompt = ChatSystemPrompt.build(enableTools: enableTools)
        }

        if let ov = systemPromptOverride, !ov.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt = ov
        }

        return prompt
    }
}
