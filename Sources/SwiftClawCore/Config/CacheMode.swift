/// Controls how the HTTP backend hints the API for prompt caching.
public enum CacheMode: String, Sendable, Codable {
    /// No caching hints sent (default). Works with all providers.
    case none
    /// Anthropic-style explicit cache_control markers on stable message prefixes.
    /// Requires the Anthropic API (auto-detected from URL or set in config).
    case anthropic
    /// OpenAI-style automatic prefix caching (no-op — caching is automatic on the server).
    /// Included for explicit configuration and future cache stat tracking.
    case openai
}
