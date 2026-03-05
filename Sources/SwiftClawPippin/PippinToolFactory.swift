import Foundation
import SwiftClawCore

/// Factory for pippin-backed tools (mail + memos).
/// Returns an empty array if the pippin binary is not installed.
public enum PippinToolFactory {
    public static func allTools() -> [any SwiftClawTool] {
        guard let runner = PippinRunner() else {
            return []
        }
        return [
            MailListTool(runner: runner),
            MailSearchTool(runner: runner),
            MailShowTool(runner: runner),
            MailSendTool(runner: runner),
            MailMarkTool(runner: runner),
            MailMoveTool(runner: runner),
            MemosListTool(runner: runner),
            MemosInfoTool(runner: runner),
            MemosTranscribeTool(runner: runner),
        ]
    }
}
