extension Session {
    /// Returns `true` when the assistant's last response in a Build-mode session
    /// was pure text (no XML action) — the model described a plan without starting
    /// to build. The caller should append `BuildSystemPrompt.firstRoundNudge` as a
    /// synthetic user turn to push the model into emitting its first action.
    public func needsBuildNudge(mode: SessionMode, lastAssistantText: String) -> Bool {
        guard mode == .build else { return false }
        let hasAction = lastAssistantText.contains("<action ")
        return !hasAction && !lastAssistantText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
