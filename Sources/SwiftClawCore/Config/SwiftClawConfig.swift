import Foundation

/// Top-level agent configuration loaded from ~/.swiftclaw/config.json.
public struct SwiftClawConfig: Sendable, Codable {
    public var fileSandbox: FileSandboxConfig
    public var embeddingModelId: String
    public var embeddingDimensions: Int
    public var retrievalTopK: Int
    public var retrievalThreshold: Float
    public var memoryEnabled: Bool
    public var consolidationInterval: Int
    public var compressionTokenThreshold: Int?
    public var cacheMode: CacheMode
    public var skillsEnabled: Bool
    public var skillsDirectory: String?
    public var credentialProxyEnabled: Bool
    public var credentialProxyExtraPatterns: [String]

    public static let `default` = SwiftClawConfig(
        fileSandbox: .default,
        embeddingModelId: "nomic-ai/nomic-embed-text-v1.5",
        embeddingDimensions: 768,
        retrievalTopK: 10,
        retrievalThreshold: 0.3,
        memoryEnabled: false,
        consolidationInterval: 3,
        compressionTokenThreshold: nil,
        cacheMode: .none,
        skillsEnabled: false,
        skillsDirectory: nil,
        credentialProxyEnabled: true,
        credentialProxyExtraPatterns: []
    )

    public init(
        fileSandbox: FileSandboxConfig = .default,
        embeddingModelId: String = "nomic-ai/nomic-embed-text-v1.5",
        embeddingDimensions: Int = 768,
        retrievalTopK: Int = 10,
        retrievalThreshold: Float = 0.3,
        memoryEnabled: Bool = false,
        consolidationInterval: Int = 3,
        compressionTokenThreshold: Int? = nil,
        cacheMode: CacheMode = .none,
        skillsEnabled: Bool = false,
        skillsDirectory: String? = nil,
        credentialProxyEnabled: Bool = true,
        credentialProxyExtraPatterns: [String] = []
    ) {
        self.fileSandbox = fileSandbox
        self.embeddingModelId = embeddingModelId
        self.embeddingDimensions = embeddingDimensions
        self.retrievalTopK = retrievalTopK
        self.retrievalThreshold = retrievalThreshold
        self.memoryEnabled = memoryEnabled
        self.consolidationInterval = consolidationInterval
        self.compressionTokenThreshold = compressionTokenThreshold
        self.cacheMode = cacheMode
        self.skillsEnabled = skillsEnabled
        self.skillsDirectory = skillsDirectory
        self.credentialProxyEnabled = credentialProxyEnabled
        self.credentialProxyExtraPatterns = credentialProxyExtraPatterns
    }

    /// Custom Codable init for backward compatibility — old JSON without new fields decodes cleanly.
    enum CodingKeys: String, CodingKey {
        case fileSandbox
        case embeddingModelId
        case embeddingDimensions
        case retrievalTopK
        case retrievalThreshold
        case memoryEnabled
        case consolidationInterval
        case compressionTokenThreshold
        case cacheMode
        case skillsEnabled
        case skillsDirectory
        case credentialProxyEnabled
        case credentialProxyExtraPatterns
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fileSandbox = try c.decodeIfPresent(FileSandboxConfig.self, forKey: .fileSandbox) ?? .default
        embeddingModelId = try c.decodeIfPresent(String.self, forKey: .embeddingModelId) ?? "nomic-ai/nomic-embed-text-v1.5"
        embeddingDimensions = try c.decodeIfPresent(Int.self, forKey: .embeddingDimensions) ?? 768
        retrievalTopK = try c.decodeIfPresent(Int.self, forKey: .retrievalTopK) ?? 10
        retrievalThreshold = try c.decodeIfPresent(Float.self, forKey: .retrievalThreshold) ?? 0.3
        memoryEnabled = try c.decodeIfPresent(Bool.self, forKey: .memoryEnabled) ?? false
        consolidationInterval = try c.decodeIfPresent(Int.self, forKey: .consolidationInterval) ?? 3
        compressionTokenThreshold = try c.decodeIfPresent(Int.self, forKey: .compressionTokenThreshold)
        cacheMode = try c.decodeIfPresent(CacheMode.self, forKey: .cacheMode) ?? .none
        skillsEnabled = try c.decodeIfPresent(Bool.self, forKey: .skillsEnabled) ?? false
        skillsDirectory = try c.decodeIfPresent(String.self, forKey: .skillsDirectory)
        credentialProxyEnabled = try c.decodeIfPresent(Bool.self, forKey: .credentialProxyEnabled) ?? true
        credentialProxyExtraPatterns = try c.decodeIfPresent([String].self, forKey: .credentialProxyExtraPatterns) ?? []
    }

    /// Builds a `CredentialProxy` from config. Pass `disableProxy: true` for CLI `--no-credential-proxy`.
    public func makeCredentialProxy(disableProxy: Bool = false) -> any CredentialProxy {
        guard !disableProxy, credentialProxyEnabled else { return NoOpCredentialProxy() }
        return RegexCredentialProxy(
            extraPatterns: credentialProxyExtraPatterns.map { (RegexCredentialProxy.customLabel, $0) }
        )
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
