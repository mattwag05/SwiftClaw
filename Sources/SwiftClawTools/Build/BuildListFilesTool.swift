import Foundation
import SwiftClawCore

/// Lists files in the session workspace. Skips dotfiles and node_modules. Caps at 200 entries.
public struct BuildListFilesTool: SwiftClawTool {
    public let name = "list_files"
    public let requiresConfirmation = false
    public let description = "List files in the workspace directory tree. Skips dotfiles and node_modules. Max 200 entries."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "path": .string(description: "Relative path to list (default: workspace root)"),
        ],
        required: []
    )

    private let workspaceURL: URL
    private static let maxEntries = 200
    private static let skipNames: Set<String> = ["node_modules", ".git", ".DS_Store"]

    public init(workspaceURL: URL) {
        self.workspaceURL = workspaceURL
    }

    private struct Arguments: Decodable {
        var path: String?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = (try? JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8)))

        let baseURL: URL
        if let p = args?.path, !p.isEmpty {
            do {
                baseURL = try WorkspaceSandbox.resolve(path: p, in: workspaceURL)
            } catch {
                return .failure(error.localizedDescription)
            }
        } else {
            baseURL = workspaceURL
        }

        var entries: [String] = []
        collect(url: baseURL, relative: "", into: &entries)

        if entries.isEmpty {
            return .success("(workspace is empty)")
        }

        var output = entries.prefix(Self.maxEntries).joined(separator: "\n")
        if entries.count > Self.maxEntries {
            output += "\n[Truncated — \(entries.count) entries total, showing first \(Self.maxEntries)]"
        }
        return .success(output)
    }

    private func collect(url: URL, relative: String, into entries: inout [String]) {
        guard entries.count < Self.maxEntries else { return }
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles
        ) else { return }

        let sorted = items.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for item in sorted {
            guard entries.count < Self.maxEntries else { return }
            let name = item.lastPathComponent
            guard !name.hasPrefix(".") && !Self.skipNames.contains(name) else { continue }

            let relPath = relative.isEmpty ? name : "\(relative)/\(name)"
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if isDir {
                entries.append("\(relPath)/")
                collect(url: item, relative: relPath, into: &entries)
            } else {
                entries.append(relPath)
            }
        }
    }
}
