import Darwin
import Foundation
import SwiftClawCore

/// Finds files matching a glob pattern under a base directory.
public struct FindFilesTool: SwiftClawTool {
    public let name = "find_files"
    public let description =
        "Find files matching a glob pattern under a base directory. Uses fnmatch-style patterns (e.g. '*.swift', 'test_*')."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "pattern": .string(description: "Glob pattern to match filenames (e.g. '*.swift')"),
            "path":    .string(description: "Base directory to search (default: ~)"),
        ],
        required: ["pattern"]
    )

    private let sandbox: FileSandbox

    public init(sandbox: FileSandbox = FileSandbox()) {
        self.sandbox = sandbox
    }

    private struct Arguments: Decodable {
        var pattern: String
        var path: String?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        let basePath = args.path ?? "~"
        let resolved: String
        do {
            resolved = try sandbox.validate(path: basePath)
        } catch {
            return .failure(error.localizedDescription)
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir),
              isDir.boolValue else {
            return .failure("Base path '\(resolved)' is not a directory")
        }

        let pattern = args.pattern
        let cap = 500
        var results: [String] = []

        guard let enumerator = FileManager.default.enumerator(atPath: resolved) else {
            return .failure("Could not enumerate directory")
        }

        let allItems = enumerator.allObjects.compactMap { $0 as? String }
        for item in allItems {
            let filename = URL(fileURLWithPath: item).lastPathComponent
            if fnmatch(pattern, filename, 0) == 0 {
                results.append(resolved + "/" + item)
            }
            if results.count >= cap { break }
        }

        if results.isEmpty {
            return .success("No files found matching '\(pattern)' under \(resolved)")
        }

        let truncated = results.count == cap ? "\n(capped at \(cap) results)" : ""
        return .success(results.joined(separator: "\n") + truncated)
    }
}
