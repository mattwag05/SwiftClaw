import Foundation
import SwiftClawCore

/// Replaces an exact string within a workspace file (optionally all occurrences).
public struct BuildEditFileTool: SwiftClawTool {
    public let name = "edit_file"
    public let requiresConfirmation = false
    public let description =
        "Replace an exact string in a file. Use replace_all to change every occurrence."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "path":        .string(description: "Relative path from workspace root"),
            "old_string":  .string(description: "Exact string to find and replace"),
            "new_string":  .string(description: "Replacement string"),
            "replace_all": .boolean(description: "Replace every occurrence (default false)"),
        ],
        required: ["path", "old_string", "new_string"]
    )

    private let workspaceURL: URL

    public init(workspaceURL: URL) {
        self.workspaceURL = workspaceURL
    }

    private struct Arguments: Decodable {
        var path: String
        var old_string: String
        var new_string: String
        var replace_all: Bool?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        let targetURL: URL
        do {
            targetURL = try WorkspaceSandbox.resolve(path: args.path, in: workspaceURL)
        } catch {
            return .failure(error.localizedDescription)
        }

        let data: Data
        do {
            data = try Data(contentsOf: targetURL)
        } catch {
            return .failure("Could not read file: \(error.localizedDescription)")
        }

        guard var text = String(data: data, encoding: .utf8) else {
            return .failure("File is not valid UTF-8: \(args.path)")
        }

        guard text.contains(args.old_string) else {
            return .failure("old_string not found in \(args.path)")
        }

        let replaceAll = args.replace_all ?? false
        if replaceAll {
            text = text.replacingOccurrences(of: args.old_string, with: args.new_string)
        } else {
            guard let range = text.range(of: args.old_string) else {
                return .failure("old_string not found in \(args.path)")
            }
            text.replaceSubrange(range, with: args.new_string)
        }

        guard let newData = text.data(using: .utf8) else {
            return .failure("Edited content could not be encoded as UTF-8")
        }

        let dir = targetURL.deletingLastPathComponent()
        let tempURL = dir.appendingPathComponent(".\(targetURL.lastPathComponent).swiftclaw-tmp")
        do {
            try newData.write(to: tempURL)
            _ = try FileManager.default.replaceItemAt(targetURL, withItemAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return .failure("Write failed: \(error.localizedDescription)")
        }

        return .success("Edited \(args.path)")
    }
}
