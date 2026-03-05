import Foundation
import SwiftClawCore

/// Lists the contents of a directory within the sandbox.
public struct ListDirectoryTool: SwiftClawTool {
    public let name = "list_directory"
    public let description =
        "List the contents of a directory. Shows files, subdirectories, and symlinks with type indicators."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "path":      .string(description: "Absolute or ~-relative path to the directory"),
            "recursive": .boolean(description: "Recursively list subdirectories (default: false)"),
        ],
        required: ["path"]
    )

    private let sandbox: FileSandbox

    public init(sandbox: FileSandbox = FileSandbox()) {
        self.sandbox = sandbox
    }

    private struct Arguments: Decodable {
        var path: String
        var recursive: Bool?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            path = try c.decode(String.self, forKey: .path)
            if let b = try? c.decodeIfPresent(Bool.self, forKey: .recursive) {
                recursive = b
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .recursive) {
                recursive = s.lowercased() == "true"
            } else { recursive = nil }
        }

        enum CodingKeys: String, CodingKey { case path, recursive }
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        let resolved: String
        do {
            resolved = try sandbox.validate(path: args.path)
        } catch {
            return .failure(error.localizedDescription)
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir) else {
            return .failure("Path not found: \(resolved)")
        }
        guard isDir.boolValue else {
            return .failure("'\(resolved)' is not a directory")
        }

        let fm = FileManager.default
        let recursive = args.recursive ?? false
        let cap = 1000
        var entries: [String] = []

        if recursive {
            guard let enumerator = fm.enumerator(atPath: resolved) else {
                return .failure("Could not enumerate directory")
            }
            let allItems = enumerator.allObjects.compactMap { $0 as? String }
            for item in allItems.prefix(cap) {
                let fullPath = resolved + "/" + item
                entries.append(item + typeIndicator(for: fullPath, fm: fm))
            }
        } else {
            let items = (try? fm.contentsOfDirectory(atPath: resolved)) ?? []
            for item in items.sorted() {
                let fullPath = resolved + "/" + item
                entries.append(item + typeIndicator(for: fullPath, fm: fm))
                if entries.count >= cap { break }
            }
        }

        let truncated = entries.count == cap ? "\n(capped at \(cap) entries)" : ""
        let output = resolved + "/\n" + entries.joined(separator: "\n") + truncated
        return .success(output)
    }

    private func typeIndicator(for path: String, fm: FileManager) -> String {
        if (try? fm.destinationOfSymbolicLink(atPath: path)) != nil {
            return " -> (symlink)"
        }
        var isDir: ObjCBool = false
        fm.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue ? "/" : ""
    }
}
