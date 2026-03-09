import Foundation

/// The outcome of an A/B adapter evaluation session.
public struct EvalResult: Codable, Sendable {
    public enum Winner: String, Codable, Sendable {
        case a, b, tie, skip
    }

    public let timestamp: Date
    public let modelId: String
    public let adapterA: String?   // nil = base model
    public let adapterB: String?
    public let prompt: String
    public let responseA: String
    public let responseB: String
    public let winner: Winner?

    public init(
        timestamp: Date = Date(),
        modelId: String,
        adapterA: String?,
        adapterB: String?,
        prompt: String,
        responseA: String,
        responseB: String,
        winner: Winner?
    ) {
        self.timestamp = timestamp
        self.modelId = modelId
        self.adapterA = adapterA
        self.adapterB = adapterB
        self.prompt = prompt
        self.responseA = responseA
        self.responseB = responseB
        self.winner = winner
    }
}

/// Persists `EvalResult` values to `~/.swiftclaw/evals/`.
public struct EvalStore: Sendable {

    public let evalsURL: URL

    public init() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appending(path: ".swiftclaw/evals", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.evalsURL = dir
    }

    public func save(_ result: EvalResult) throws {
        // Use Unix timestamp for filename — sortable, unique, no formatter needed.
        let ts = String(format: "%.3f", result.timestamp.timeIntervalSince1970)
        let filename = "eval-\(ts).json"
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        let url = evalsURL.appending(path: filename)
        try data.write(to: url, options: .atomic)
    }
}
