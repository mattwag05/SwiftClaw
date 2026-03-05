import AppKit
import Foundation
import SwiftClawCore

/// Reads from or writes to the macOS clipboard.
public struct ClipboardTool: SwiftClawTool {
    public let name = "clipboard"
    public let description = "Read from or write to the macOS clipboard."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "action":  .enumeration(values: ["read", "write"],
                                    description: "Whether to read or write the clipboard"),
            "content": .string(description: "Text to write (required for write action)"),
        ],
        required: ["action"]
    )

    public init() {}

    private struct Arguments: Decodable {
        var action: String
        var content: String?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        switch args.action {
        case "read":
            let text = await MainActor.run {
                NSPasteboard.general.string(forType: .string) ?? ""
            }
            return text.isEmpty ? .success("(clipboard is empty)") : .success(text)

        case "write":
            guard let content = args.content else {
                return .failure("'content' is required for write action")
            }
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(content, forType: .string)
            }
            return .success("Wrote \(content.count) characters to clipboard")

        default:
            return .failure("Unknown action '\(args.action)'. Use 'read' or 'write'.")
        }
    }
}
