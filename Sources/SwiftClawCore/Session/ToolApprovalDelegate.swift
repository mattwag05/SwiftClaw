/// Delegate that decides whether a tool call should proceed.
///
/// Implementations on UI layers present approve/deny UI;
/// CLI or tests return `true` (auto-approve all tools).
public protocol ToolApprovalDelegate: Sendable {
    func shouldExecute(toolName: String, callId: String, arguments: String) async -> Bool
}
