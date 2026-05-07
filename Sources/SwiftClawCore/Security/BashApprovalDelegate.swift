/// The result of a bash command approval request.
public enum BashApprovalResult: Sendable {
    /// Run this command once only.
    case allowOnce
    /// Auto-approve this command for the rest of the session.
    case allowSession
    /// Add the command prefix to the persistent allowlist.
    case addToAllowlist
    /// Block execution.
    case deny
}

/// Delegate that decides whether a `run_bash` command should execute.
///
/// UI implementations show a system notification with four choices;
/// CLI implementations prompt on stderr; tests return `.allowOnce` unconditionally.
public protocol BashApprovalDelegate: Sendable {
    func approveBash(command: String, requestId: String) async -> BashApprovalResult
}
