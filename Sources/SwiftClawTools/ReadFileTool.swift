import Foundation
import SwiftClawCore

/// Reads the contents of a text file within the sandbox.
public struct ReadFileTool: SwiftClawTool {
    public let name = "read_file"
    public let description =
        "Read the contents of a text file. Returns up to `limit` lines starting at `offset`. Binary files are detected and rejected."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "path":   .string(description: "Absolute or ~-relative path to the file"),
            "offset": .integer(description: "Line number to start reading from (1-based, default: 1)"),
            "limit":  .integer(description: "Maximum lines to return (default: 1000)"),
        ],
        required: ["path"]
    )

    private let sandbox: FileSandbox

    public init(sandbox: FileSandbox = FileSandbox()) {
        self.sandbox = sandbox
    }

    private struct Arguments: Decodable {
        var path: String
        var offset: Int?
        var limit: Int?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            path = try c.decode(String.self, forKey: .path)
            if let i = try? c.decodeIfPresent(Int.self, forKey: .offset) {
                offset = i
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .offset) {
                offset = Int(s)
            } else { offset = nil }
            if let i = try? c.decodeIfPresent(Int.self, forKey: .limit) {
                limit = i
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .limit) {
                limit = Int(s)
            } else { limit = nil }
        }

        enum CodingKeys: String, CodingKey { case path, offset, limit }
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        let resolved: String
        do {
            resolved = try sandbox.validate(path: args.path)
        } catch {
            return .failure(error.localizedDescription)
        }

        guard FileManager.default.fileExists(atPath: resolved) else {
            return .failure("File not found: \(resolved)")
        }

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir)
        if isDir.boolValue {
            return .failure("'\(resolved)' is a directory, not a file")
        }

        guard let data = FileManager.default.contents(atPath: resolved) else {
            return .failure("Could not read file: \(resolved)")
        }

        // Binary detection: look for null bytes in first 8 KB
        let probe = data.prefix(8192)
        if probe.contains(0x00) {
            return .failure("File appears to be binary: \(resolved)")
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return .failure("File is not valid UTF-8: \(resolved)")
        }

        let limit = args.limit ?? 1000
        let offsetIndex = max(1, args.offset ?? 1) - 1  // convert to 0-based

        let lines = text.components(separatedBy: "\n")
        let slice = Array(lines.dropFirst(offsetIndex).prefix(limit))
        let startLine = offsetIndex + 1
        let endLine = offsetIndex + slice.count
        let header = "// \(resolved) (lines \(startLine)-\(endLine) of \(lines.count))"

        return .success(header + "\n" + slice.joined(separator: "\n"))
    }
}
