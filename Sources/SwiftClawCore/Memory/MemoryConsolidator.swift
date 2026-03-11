import Foundation

/// Extracts memorable facts from a conversation and persists them to AgentMemory.
///
/// Stateless — create once and reuse across turns.
public struct MemoryConsolidator: Sendable {
    public init() {}

    /// Ask the model to extract key facts from `messages` and write them to `memory`.
    /// - Returns: The keys that were written.
    public func consolidate(
        messages: [Message],
        using backend: any ModelBackend,
        config: GenerationConfig,
        into memory: AgentMemory,
        sessionId: String
    ) async throws -> [String] {
        let conversationText = messages
            .filter { $0.role == .user || $0.role == .assistant }
            .map { "\($0.role == .user ? "User" : "Assistant"): \($0.content)" }
            .joined(separator: "\n")

        guard !conversationText.isEmpty else { return [] }

        let systemMsg = Message(
            role: .system,
            content: """
                You are a memory extraction assistant. \
                Extract key facts, user preferences, and important corrections from the conversation below. \
                Return a JSON array of objects with "key" (short identifier) and "content" (the fact). \
                Example: [{"key":"preferred-editor","content":"User prefers Neovim"}]. \
                Return [] if nothing is worth remembering. \
                Return ONLY valid JSON — no explanation, no markdown fences.
                """
        )
        let userMsg = Message(
            role: .user,
            content: "Conversation:\n\(conversationText)"
        )

        let noToolConfig = GenerationConfig(
            temperature: config.temperature,
            maxTokens: min(config.maxTokens, 1024)
        )

        let response = try await backend.generate(
            messages: [systemMsg, userMsg],
            tools: [],
            config: noToolConfig
        )

        let raw = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

        struct RawEntry: Decodable {
            let key: String
            let content: String
        }

        var writtenKeys: [String] = []

        if let data = raw.data(using: .utf8),
           let entries = try? JSONDecoder().decode([RawEntry].self, from: data) {
            for entry in entries where !entry.key.isEmpty && !entry.content.isEmpty {
                let memEntry = MemoryEntry(key: entry.key, content: entry.content, source: sessionId)
                try await memory.set(entry.key, entry: memEntry)
                writtenKeys.append(entry.key)
            }
        } else if !raw.isEmpty {
            // Fallback: store entire response as a single fact
            let key = "fact-\(Int(Date().timeIntervalSince1970))"
            let memEntry = MemoryEntry(key: key, content: raw, source: sessionId)
            try await memory.set(key, entry: memEntry)
            writtenKeys.append(key)
        }

        return writtenKeys
    }
}
