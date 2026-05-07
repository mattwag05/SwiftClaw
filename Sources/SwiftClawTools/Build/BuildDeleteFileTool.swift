import Foundation
import SwiftClawCore

/// Deletes a file or empty directory from the session workspace.
public struct BuildDeleteFileTool: SwiftClawTool {
    public let name = "delete_file"
    public let requiresConfirmation = false
    public let description = "Delete a file or empty directory from the workspace."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "path": .string(description: "Relative path from workspace root"),
        ],
        required: ["path"]
    )

    private let workspaceURL: URL

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
            return .failure("Not found: \(args.path)")
        }

        do {
            try FileManager.default.removeItem(at: targetURL)
        } catch {
            return .failure("Delete failed: \(error.localizedDescription)")
        }

        return .success("Deleted \(args.path)")
    }
}
