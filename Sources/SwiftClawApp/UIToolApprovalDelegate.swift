import SwiftClawCore

/// Bridges Session's tool approval to the MainActor UI layer.
struct UIToolApprovalDelegate: ToolApprovalDelegate {
    let handler: @Sendable (String, String, String) async -> Bool

    func shouldExecute(toolName: String, callId: String, arguments: String) async -> Bool {
        await handler(toolName, callId, arguments)
    }
}
