import Foundation
import SwiftClawCore

/// Writes text content to a file within the sandbox.
public struct WriteFileTool: SwiftClawTool {
    public let name = "write_file"
    public let description =
        "Write text content to a file. Creates intermediate directories as needed. Overwrites existing files."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "path":    .string(description: "Absolute or ~-relative path to write"),
            "content": .string(description: "Text content to write"),
        ],
        required: ["path", "content"]
    )

    private let sandbox: FileSandbox

    public init(sandbox: FileSandbox = FileSandbox()) {
        self.sandbox = sandbox
    }

    private struct Arguments: Decodable {
        var path: String
        var content: String
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        let resolved: String
        do {
            resolved = try sandbox.validate(path: args.path)
        } catch {
            return .failure(error.localizedDescription)
        }

        let url = URL(fileURLWithPath: resolved)
        let dir = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return .failure("Could not create directory: \(error.localizedDescription)")
        }

        guard let data = args.content.data(using: .utf8) else {
            return .failure("Content could not be encoded as UTF-8")
        }

        // Atomic write via temp file
        let tempURL = dir.appendingPathComponent(".\(url.lastPathComponent).swiftclaw-tmp")
        do {
            try data.write(to: tempURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return .failure("Write failed: \(error.localizedDescription)")
        }

        return .success("Wrote \(data.count) bytes to \(resolved)")
    }
}
