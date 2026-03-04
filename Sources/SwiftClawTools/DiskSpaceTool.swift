import Foundation
import SwiftClawCore

/// Reports disk space usage for a given path (defaults to /).
public struct DiskSpaceTool: SwiftClawTool {
    public let name = "disk_space"
    public let description = "Check disk space usage. Optionally specify a path (defaults to /)."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "path": .string(description: "Filesystem path to check (default: /)")
        ],
        required: []
    )

    public init() {}

    private struct Arguments: Decodable {
        var path: String?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(
            Arguments.self, from: Data(arguments.utf8))
        let path = args.path ?? "/"

        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: path)
            guard let totalSize = attrs[.systemSize] as? Int64,
                  let freeSize = attrs[.systemFreeSize] as? Int64
            else {
                return .failure("Could not read filesystem attributes for \(path)")
            }

            let usedSize = totalSize - freeSize
            let usedPercent = Double(usedSize) / Double(totalSize) * 100

            let lines = [
                "Path: \(path)",
                "Total: \(formatBytes(totalSize))",
                "Used: \(formatBytes(usedSize)) (\(String(format: "%.1f", usedPercent))%)",
                "Free: \(formatBytes(freeSize))",
            ]
            return .success(lines.joined(separator: "\n"))
        } catch {
            return .failure("Failed to check disk space for '\(path)': \(error.localizedDescription)")
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }
}
