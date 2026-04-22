import Foundation

/// Abstraction over token counting for a message thread.
///
/// Implementations may return exact counts (by invoking a real tokenizer) or
/// approximate counts (e.g. a chars/4 heuristic). Callers should inspect
/// ``isApproximate`` when precision matters.
public protocol TokenCounter: Sendable {
    /// Counts tokens in a message thread. Implementations may approximate.
    func count(messages: [Message]) async -> Int

    /// Whether the count is approximate (e.g. chars/4 heuristic).
    var isApproximate: Bool { get }
}
