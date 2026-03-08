import Foundation

/// Exports SwiftClaw session messages to JSONL in OpenAI ChatML format
/// for use with MLX fine-tuning scripts and HuggingFace tooling.
public struct TraceExporter: Sendable {

    // MARK: - Public API

    /// Encode a single session's messages as one JSONL line (no trailing newline).
    public static func exportLine(messages: [Message]) throws -> Data {
        try exportAll([messages])
    }

    /// Encode multiple sessions as JSONL — one line per session, separated by `\n`.
    public static func exportAll(_ batches: [[Message]]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let lines = try batches.map { messages -> Data in
            try encoder.encode(ChatMLLine(messages: messages.map(ChatMLMessage.init)))
        }
        return Data(lines.joined(separator: Data("\n".utf8)))
    }
}

// MARK: - Internal ChatML types

private struct ChatMLLine: Encodable {
    let messages: [ChatMLMessage]
}

private struct ChatMLMessage: Encodable {
    let role: String
    let content: String?
    let tool_calls: [ChatMLToolCall]?
    let tool_call_id: String?

    init(_ message: Message) {
        self.role = message.role.rawValue
        self.tool_call_id = message.toolCallId

        if let calls = message.toolCalls, !calls.isEmpty {
            // Assistant messages that issue tool calls have null content per OpenAI spec.
            self.content = message.content.isEmpty ? nil : message.content
            self.tool_calls = calls.map(ChatMLToolCall.init)
        } else {
            self.content = message.content
            self.tool_calls = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        // Encode content as null when nil (OpenAI spec for tool-calling assistant turns).
        try container.encode(content, forKey: .content)
        if let tc = tool_calls { try container.encode(tc, forKey: .tool_calls) }
        if let id = tool_call_id { try container.encode(id, forKey: .tool_call_id) }
    }

    private enum CodingKeys: String, CodingKey {
        case role, content, tool_calls, tool_call_id
    }
}

private struct ChatMLToolCall: Encodable {
    let id: String
    let type: String = "function"
    let function: ChatMLFunction

    init(_ request: ToolCallRequest) {
        self.id = request.id
        self.function = ChatMLFunction(name: request.name, arguments: request.arguments)
    }
}

private struct ChatMLFunction: Encodable {
    let name: String
    let arguments: String
}
