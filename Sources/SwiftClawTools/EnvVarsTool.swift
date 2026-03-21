import Foundation
import SwiftClawCore

/// Reads environment variables from the current process.
public struct EnvVarsTool: SwiftClawTool {
    public let name = "env_vars"
    public let description =
        "Read environment variables. Provide a `name` for a single variable, or omit it for a sorted dump of all variables. Variables matching common credential patterns (KEY, SECRET, TOKEN, PASSWORD, etc.) are redacted in bulk dumps."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "name": .string(description: "Name of a specific environment variable (optional)"),
        ],
        required: []
    )

    public init() {}

    private struct Arguments: Decodable {
        var name: String?
    }

    /// Substrings that indicate a variable likely contains credentials or secrets.
    private static let sensitiveSubstrings: [String] = [
        "KEY", "SECRET", "TOKEN", "PASSWORD", "PASSWD", "CREDENTIAL",
        "PRIVATE", "AUTH", "ACCESS", "SESSION", "CERT", "SIGNING",
    ]

    private func isSensitive(_ name: String) -> Bool {
        let upper = name.uppercased()
        return Self.sensitiveSubstrings.contains { upper.contains($0) }
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        if let name = args.name {
            if let value = ProcessInfo.processInfo.environment[name] {
                return .success("\(name)=\(value)")
            } else {
                return .failure("Environment variable '\(name)' is not set")
            }
        }

        let sorted = ProcessInfo.processInfo.environment
            .sorted { $0.key < $1.key }
            .map { key, value in
                isSensitive(key) ? "\(key)=<redacted>" : "\(key)=\(value)"
            }
            .joined(separator: "\n")
        return .success(sorted)
    }
}
