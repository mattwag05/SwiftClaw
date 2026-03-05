import Foundation

/// Top-level agent configuration loaded from ~/.swiftclaw/config.json.
public struct SwiftClawConfig: Sendable, Codable {
    public var fileSandbox: FileSandboxConfig

    public static let `default` = SwiftClawConfig(fileSandbox: .default)

    public init(fileSandbox: FileSandboxConfig = .default) {
        self.fileSandbox = fileSandbox
    }

    /// Loads config from ~/.swiftclaw/config.json. Returns `.default` if the file doesn't exist.
    public static func load() throws -> SwiftClawConfig {
        let url = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".swiftclaw/config.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .default
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SwiftClawConfig.self, from: data)
    }
}

/// File sandbox configuration — controls which paths file tools can access.
public struct FileSandboxConfig: Sendable, Codable {
    /// Absolute or `~`-prefixed paths the agent is permitted to read/write.
    public var allowedPaths: [String]

    public static let `default` = FileSandboxConfig(allowedPaths: ["~"])

    public init(allowedPaths: [String] = ["~"]) {
        self.allowedPaths = allowedPaths
    }
}
