/// Configuration for a session's execution limits.
public struct SessionConfiguration: Sendable {
    /// Maximum tool-call round-trips per user turn before the session stops.
    public var maxToolRoundTrips: Int
    /// Maximum total messages in conversation history.
    public var maxTotalMessages: Int

    public init(maxToolRoundTrips: Int = 10, maxTotalMessages: Int = 200) {
        self.maxToolRoundTrips = maxToolRoundTrips
        self.maxTotalMessages = maxTotalMessages
    }
}
