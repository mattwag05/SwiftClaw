import Foundation

/// Summarizes older conversation history to reduce token consumption.
///
/// Stateless — create once and reuse.
public struct ContextCompressor: Sendable {
    public init() {}

    /// Rough token estimate: ~4 characters per token.
    public func estimateTokens(_ messages: [Message]) -> Int {
        messages.reduce(0) { $0 + ($1.content.count / 4) }
    }

    /// Compress `messages` by summarizing the compressible middle region.
    ///
    /// Always keeps:
    /// - `messages[0]` (system message)
    /// - The last `keepRecent` messages
    ///
    /// The middle region is summarized and injected as a `.system` recap message.
    public func compress(
        _ messages: [Message],
        using backend: any ModelBackend,
        config: GenerationConfig,
        keepRecent: Int
    ) async throws -> [Message] {
        guard messages.count > keepRecent + 1 else { return messages }

        let systemMessage = messages[0]
        let tail = Array(messages.suffix(keepRecent))
        let compressible = Array(messages.dropFirst().dropLast(keepRecent))

        guard !compressible.isEmpty else { return messages }

        let conversationText = compressible
            .map { msg -> String in
                switch msg.role {
                case .user: return "User: \(msg.content)"
                case .assistant: return "Assistant: \(msg.content)"
                case .tool: return "[Tool result: \(msg.content.prefix(200))]"
                case .system: return ""
                }
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        let summarySystem = Message(
            role: .system,
            content: "You are a summarization assistant. Summarize the following conversation concisely (max 500 words), preserving key decisions, facts established, and important context."
        )
        let summaryUser = Message(
            role: .user,
            content: "Conversation to summarize:\n\(conversationText)"
        )

        let summaryConfig = GenerationConfig(
            temperature: 0.3,
            maxTokens: min(config.maxTokens, 800)
        )

        let response = try await backend.generate(
            messages: [summarySystem, summaryUser],
            tools: [],
            config: summaryConfig
        )

        let recap = Message(
            role: .system,
            content: "## Prior Context\n\(response.content)"
        )

        return [systemMessage, recap] + tail
    }
}
