import Foundation
import SwiftClawCore

/// Writes a file within the session workspace. Applies cleanFileContent post-processing
/// and emits fileStreaming / fileWritten session events for Canvas.
public struct BuildWriteFileTool: SwiftClawTool {
    public let name = "write_file"
    public let requiresConfirmation = false
    public let description =
        "Write text content to a file in the workspace. Creates intermediate directories. Overwrites existing files."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "path":    .string(description: "Relative path from workspace root"),
            "content": .string(description: "Text content to write"),
        ],
        required: ["path", "content"]
    )

    private let workspaceURL: URL
    private let eventSink: (@Sendable (SessionEvent) -> Void)?

    public init(workspaceURL: URL, eventSink: (@Sendable (SessionEvent) -> Void)? = nil) {
        self.workspaceURL = workspaceURL
        self.eventSink = eventSink
    }

    private struct Arguments: Decodable {
        var path: String
        var content: String
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        let targetURL: URL
        do {
            targetURL = try WorkspaceSandbox.resolve(path: args.path, in: workspaceURL)
        } catch {
            return .failure(error.localizedDescription)
        }

        let cleaned = cleanFileContent(args.content, path: args.path)
        eventSink?(.fileStreaming(path: args.path, partial: cleaned))

        let dir = targetURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return .failure("Could not create directory: \(error.localizedDescription)")
        }

        guard let data = cleaned.data(using: .utf8) else {
            return .failure("Content could not be encoded as UTF-8")
        }

        // Always write via temp file. For new files try moveItem (atomic rename on same FS);
        // if the file was created concurrently, fall back to replaceItemAt. This eliminates
        // the TOCTOU window between the old fileExists check and the non-atomic write.
        let tempURL = dir.appendingPathComponent(".\(targetURL.lastPathComponent).swiftclaw-tmp")
        do {
            try data.write(to: tempURL)
            do {
                try FileManager.default.moveItem(at: tempURL, to: targetURL)
            } catch {
                _ = try FileManager.default.replaceItemAt(targetURL, withItemAt: tempURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return .failure("Write failed: \(error.localizedDescription)")
        }

        eventSink?(.fileWritten(path: args.path))
        return .success("Wrote \(data.count) bytes to \(args.path)")
    }

    /// Strips markdown fences from HTML, SVG, JSON, and generic code blocks.
    /// Mirrors Gemma's cleanFileContent logic.
    private func cleanFileContent(_ content: String, path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        let fencedTypes = ["html", "svg", "json", "css", "js", "ts", "jsx", "tsx", "xml"]

        if fencedTypes.contains(ext) || ext.isEmpty {
            if let stripped = stripFence(content) {
                return stripped
            }
        }
        return content
    }

    private func stripFence(_ content: String) -> String? {
        let lines = content.components(separatedBy: "\n")
        guard lines.count >= 2 else { return nil }
        let first = lines[0].trimmingCharacters(in: .whitespaces)
        let last = lines[lines.count - 1].trimmingCharacters(in: .whitespaces)
        guard first.hasPrefix("```") && last == "```" else { return nil }
        return lines.dropFirst().dropLast().joined(separator: "\n")
    }
}
