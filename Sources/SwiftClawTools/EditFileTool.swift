import Foundation
import SwiftClawCore

/// Performs a targeted find-and-replace edit on a text file within the sandbox.
///
/// The agent must supply the exact current content to replace (`old_string`).
/// If that string is not found in the file the edit is rejected — this prevents
/// stale edits when the file has changed since the agent last read it.
/// If the string appears more than once the edit is also rejected (ambiguous).
public struct EditFileTool: SwiftClawTool {
    public let name = "edit_file"
    public let requiresConfirmation = true
    public let description =
        """
        Replace an exact string in a file with new content. \
        old_string must match the current file content exactly (including whitespace and newlines). \
        Returns an error if old_string is not found or appears more than once (ambiguous). \
        Read the file first to confirm the exact text before calling this tool.
        """

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "path":       .string(description: "Absolute or ~-relative path to the file"),
            "old_string": .string(description: "Exact text to find and replace (must appear exactly once)"),
            "new_string": .string(description: "Replacement text"),
        ],
        required: ["path", "old_string", "new_string"]
    )

    private let sandbox: FileSandbox

    public init(sandbox: FileSandbox = FileSandbox()) {
        self.sandbox = sandbox
    }

    private struct Arguments: Decodable {
        var path: String
        var old_string: String
        var new_string: String
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        if args.old_string.isEmpty {
            return .failure("old_string must not be empty — use write_file to create or overwrite a file")
        }

        let resolved: String
        do {
            resolved = try sandbox.validate(path: args.path)
        } catch {
            return .failure(error.localizedDescription)
        }

        let url = URL(fileURLWithPath: resolved)

        let current: String
        do {
            current = try String(contentsOf: url, encoding: .utf8)
        } catch {
            return .failure("Could not read file: \(error.localizedDescription)")
        }

        var foundRange: Range<String.Index>?
        var searchStart = current.startIndex
        while let range = current.range(of: args.old_string, range: searchStart..<current.endIndex) {
            if foundRange != nil {
                return .failure(
                    "old_string appears more than once in \(resolved) — edit is ambiguous. " +
                    "Use a longer, unique old_string that includes surrounding context."
                )
            }
            foundRange = range
            searchStart = range.upperBound
        }

        guard let matchRange = foundRange else {
            return .failure(
                "old_string not found in \(resolved). " +
                "Re-read the file with read_file to confirm the exact current content."
            )
        }

        let updated = current.replacingCharacters(in: matchRange, with: args.new_string)

        guard let data = updated.data(using: .utf8) else {
            return .failure("Updated content could not be encoded as UTF-8")
        }

        let dir = url.deletingLastPathComponent()
        let tempURL = dir.appendingPathComponent(".\(url.lastPathComponent).swiftclaw-tmp")
        do {
            try data.write(to: tempURL)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return .failure("Write failed: \(error.localizedDescription)")
        }

        let oldLineCount = args.old_string.lazy.filter { $0 == "\n" }.count + 1
        let newLineCount = args.new_string.lazy.filter { $0 == "\n" }.count + 1
        let delta = newLineCount - oldLineCount
        let deltaStr = delta == 0 ? "same line count" : (delta > 0 ? "+\(delta) lines" : "\(delta) lines")
        return .success("Edited \(resolved): replaced \(oldLineCount) line(s) with \(newLineCount) line(s) (\(deltaStr))")
    }
}
