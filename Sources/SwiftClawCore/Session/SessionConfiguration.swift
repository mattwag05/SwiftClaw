/// Configuration for a session's execution limits and memory behavior.
public struct SessionConfiguration: Sendable {
    /// Maximum tool-call round-trips per user turn before the session stops.
    public var maxToolRoundTrips: Int
    /// Maximum total messages in conversation history.
    public var maxTotalMessages: Int

    // MARK: - Memory / consolidation (opt-in)

    /// Enable LLM-driven memory consolidation. Default: false (backward compatible).
    public var memoryEnabled: Bool
    /// Run consolidation every N user turns. Only used when `memoryEnabled` is true.
    public var consolidationInterval: Int
    /// Estimated token threshold for context compression. nil = disabled.
    public var compressionTokenThreshold: Int?
    /// Number of recent messages to keep verbatim during compression.
    public var compressionKeepRecent: Int

    // MARK: - Memory retrieval

    /// Maximum memories to inject per turn. Mirrors `SwiftClawConfig.retrievalTopK`.
    public var retrievalTopK: Int
    /// Minimum relevance score for memory injection. Mirrors `SwiftClawConfig.retrievalThreshold`.
    public var retrievalThreshold: Float

    public init(
        maxToolRoundTrips: Int = 10,
        maxTotalMessages: Int = 200,
        memoryEnabled: Bool = false,
        consolidationInterval: Int = 3,
        compressionTokenThreshold: Int? = nil,
        compressionKeepRecent: Int = 10,
        retrievalTopK: Int = 10,
        retrievalThreshold: Float = 0.3
    ) {
        self.maxToolRoundTrips = maxToolRoundTrips
        self.maxTotalMessages = maxTotalMessages
        self.memoryEnabled = memoryEnabled
        self.consolidationInterval = consolidationInterval
        self.compressionTokenThreshold = compressionTokenThreshold
        self.compressionKeepRecent = compressionKeepRecent
        self.retrievalTopK = retrievalTopK
        self.retrievalThreshold = retrievalThreshold
    }
}
