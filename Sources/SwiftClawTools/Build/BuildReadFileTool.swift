import Foundation
import SwiftClawCore

/// Reads a file from the session workspace with a 20 000-character truncation limit.
public struct BuildReadFileTool: SwiftClawTool {
    public let name = "read_file"
    public let requiresConfirmation = false
    public let description = "Read the contents of a file in the workspace. Truncates at 20 000 characters."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "path": .string(description: "Relative path from workspace root"),
        ],
        required: ["path"]
    )

    private let workspaceURL: URL
    private static let maxChars = 20_000

    public init(workspaceURL: URL) {
        self.workspaceURL = workspaceURL
    }

    private struct Arguments: Decodable {
        var path: String
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        let targetURL: URL
        do {
            targetURL = try WorkspaceSandbox.resolve(path: args.path, in: workspaceURL)
        } catch {
            return .failure(error.localizedDescription)
        }

        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            return .failure("File not found: \(args.path)")
        }

        let data: Data
        do {
            data = try Data(contentsOf: targetURL)
        } catch {
            return .failure("Could not read file: \(error.localizedDescription)")
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return .failure("File is not valid UTF-8: \(args.path)")
        }

        if text.count > Self.maxChars {
            let truncated = String(text.prefix(Self.maxChars))
            return .success(truncated + "\n\n[Truncated — \(text.count) chars total, showing first \(Self.maxChars)]")
        }
        return .success(text)
    }
}
