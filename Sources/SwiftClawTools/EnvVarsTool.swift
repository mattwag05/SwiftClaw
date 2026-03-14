import Foundation
import SwiftClawCore

/// Reads environment variables from the current process.
public struct EnvVarsTool: SwiftClawTool {
    public let name = "env_vars"
    public let description =
        "Read environment variables. Provide a `name` for a single variable, or omit it for a sorted dump of all variables. Variables whose names suggest credentials (API keys, tokens, passwords, secrets) have their values redacted."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "name": .string(description: "Name of a specific environment variable (optional)"),
        ],
        required: []
    )

    public init() {}

    /// Substrings that flag a variable as potentially sensitive.
    private static let sensitivePatterns: [String] = [
        "KEY", "TOKEN", "SECRET", "PASSWORD", "PASSWD", "CREDENTIAL",
        "AUTH", "PRIVATE", "CERT", "SESSION",
    ]

    private static func isSensitive(_ name: String) -> Bool {
        let upper = name.uppercased()
        return sensitivePatterns.contains { upper.contains($0) }
    }

    private static func redactedValue(for name: String, value: String) -> String {
        isSensitive(name) ? "[REDACTED]" : value
    }

    private struct Arguments: Decodable {
        var name: String?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        if let name = args.name {
            if let value = ProcessInfo.processInfo.environment[name] {
                let display = Self.redactedValue(for: name, value: value)
                return .success("\(name)=\(display)")
            } else {
                return .failure("Environment variable '\(name)' is not set")
            }
        }

        let sorted = ProcessInfo.processInfo.environment
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(Self.redactedValue(for: $0.key, value: $0.value))" }
            .joined(separator: "\n")
        return .success(sorted)
    }
}
