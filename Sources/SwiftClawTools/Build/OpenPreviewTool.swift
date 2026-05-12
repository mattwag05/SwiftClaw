import Foundation
import SwiftClawCore

/// Signals to the Canvas that the workspace preview should be opened.
///
/// Returns a no-op signal with the `swiftclaw-workspace://` URL so the model
/// knows the URL it can reference in subsequent instructions.
public struct OpenPreviewTool: SwiftClawTool {
    public let name = "open_preview"
    public let requiresConfirmation = false
    public let description = "Open the Canvas preview pane showing the workspace output."

    public let parameterSchema: JSONSchema = .object(properties: [:], required: [])

    private let sessionId: String

    public init(sessionId: String) {
        self.sessionId = sessionId
    }

    public func execute(arguments: String) async throws -> ToolResult {
        .success("Preview is live at swiftclaw-workspace://\(sessionId)/")
    }
}
