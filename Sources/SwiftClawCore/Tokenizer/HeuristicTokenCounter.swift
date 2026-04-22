import Foundation

/// A cheap, dependency-free token counter that approximates token count as
/// `max(1, totalCharacters / 4)`.
///
/// Counts the visible ``Message/content`` plus any ``Message/toolCalls`` (tool
/// name + JSON-encoded arguments) and ``Message/toolCallId``, since those
/// strings are serialized to the model on the wire. The 4-char-per-token ratio
/// is a conservative rule of thumb for English + code and is sufficient for
/// context-budget UI gauges.
public struct HeuristicTokenCounter: TokenCounter {
    public init() {}

    public var isApproximate: Bool {
        true
    }

    public func count(messages: [Message]) async -> Int {
        let chars = messages.reduce(0) { acc, message in
            var total = acc + message.content.count
            if let toolCalls = message.toolCalls {
                for call in toolCalls {
                    total += call.name.count + call.arguments.count
                }
            }
            if let toolCallId = message.toolCallId {
                total += toolCallId.count
            }
            return total
        }
        return max(1, chars / 4)
    }
}
