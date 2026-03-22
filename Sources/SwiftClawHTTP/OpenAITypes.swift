import Foundation
import SwiftClawCore

// MARK: - Request

struct StreamOptions: Encodable {
    let includeUsage: Bool
    enum CodingKeys: String, CodingKey {
        case includeUsage = "include_usage"
    }
}

struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let tools: [OpenAIToolDefinition]?
    let stream: Bool
    let streamOptions: StreamOptions?
    let temperature: Float
    let maxTokens: Int
    let topP: Float?

    enum CodingKeys: String, CodingKey {
        case model, messages, tools, stream, temperature, topP = "top_p"
        case maxTokens = "max_tokens"
        case streamOptions = "stream_options"
    }
}

// MARK: - Anthropic Cache Control

/// Marks a content block for Anthropic prompt caching.
struct AnthropicCacheControl: Encodable, Equatable {
    let type: String  // always "ephemeral"
    static let ephemeral = AnthropicCacheControl(type: "ephemeral")
}

/// An Anthropic-style structured content block (text + optional cache marker).
struct AnthropicContentBlock: Encodable, Equatable {
    let type: String  // always "text"
    let text: String
    let cacheControl: AnthropicCacheControl?

    enum CodingKeys: String, CodingKey {
        case type, text
        case cacheControl = "cache_control"
    }
}

/// Flexible message content: either a plain string or an array of Anthropic content blocks.
enum MessageContent: Encodable, Equatable {
    case string(String)
    case contentBlocks([AnthropicContentBlock])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s):
            try container.encode(s)
        case .contentBlocks(let blocks):
            try container.encode(blocks)
        }
    }
}

// MARK: - Messages

struct OpenAIMessage: Encodable {
    let role: String
    let content: MessageContent?
    let toolCalls: [OpenAIToolCall]?
    let toolCallId: String?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(toolCalls, forKey: .toolCalls)
        try container.encodeIfPresent(toolCallId, forKey: .toolCallId)
    }
}

struct OpenAIToolCall: Codable {
    let id: String
    let type: String
    let function: OpenAIFunctionCall
}

struct OpenAIFunctionCall: Codable {
    let name: String
    let arguments: String
}

struct OpenAIToolDefinition: Encodable {
    let type: String
    let function: OpenAIFunctionDefinition
    let cacheControl: AnthropicCacheControl?  // nil for non-Anthropic mode

    enum CodingKeys: String, CodingKey {
        case type, function
        case cacheControl = "cache_control"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(function, forKey: .function)
        try container.encodeIfPresent(cacheControl, forKey: .cacheControl)
    }
}

struct OpenAIFunctionDefinition: Encodable {
    let name: String
    let description: String
    let parameters: JSONSchema

    init(from definition: ToolDefinition) {
        self.name = definition.name
        self.description = definition.description
        self.parameters = definition.parameters
    }
}

// MARK: - SSE Response

struct UsagePayload: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        promptTokens = try c.decode(Int.self, forKey: .promptTokens)
        completionTokens = try c.decode(Int.self, forKey: .completionTokens)
        totalTokens = try c.decode(Int.self, forKey: .totalTokens)
        cacheReadInputTokens = try c.decodeIfPresent(Int.self, forKey: .cacheReadInputTokens)
        cacheCreationInputTokens = try c.decodeIfPresent(Int.self, forKey: .cacheCreationInputTokens)
    }
}

struct ChatCompletionChunk: Decodable {
    let choices: [ChunkChoice]
    let usage: UsagePayload?
}

struct ChunkChoice: Decodable {
    let delta: ChunkDelta
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

struct ChunkDelta: Decodable {
    let content: String?
    let toolCalls: [DeltaToolCall]?

    enum CodingKeys: String, CodingKey {
        case content
        case toolCalls = "tool_calls"
    }
}

struct DeltaToolCall: Decodable {
    let index: Int
    let id: String?
    let function: DeltaFunction?
}

struct DeltaFunction: Decodable {
    let name: String?
    let arguments: String?
}

// MARK: - Conversion helpers

extension OpenAIMessage {
    init(from message: Message) {
        switch message.role {
        case .system:
            self.init(role: "system", content: .string(message.content), toolCalls: nil, toolCallId: nil)
        case .user:
            self.init(role: "user", content: .string(message.content), toolCalls: nil, toolCallId: nil)
        case .assistant:
            let calls = message.toolCalls.map { tcs in
                tcs.map { tc in
                    OpenAIToolCall(
                        id: tc.id,
                        type: "function",
                        function: OpenAIFunctionCall(name: tc.name, arguments: tc.arguments)
                    )
                }
            }
            // OpenAI requires content key to be absent (not null) when tool_calls present
            let content: MessageContent? = (message.toolCalls?.isEmpty == false) ? nil : .string(message.content)
            self.init(role: "assistant", content: content, toolCalls: calls, toolCallId: nil)
        case .tool:
            self.init(role: "tool", content: .string(message.content), toolCalls: nil, toolCallId: message.toolCallId)
        }
    }
}

extension OpenAIToolDefinition {
    init(from definition: ToolDefinition) {
        self.init(
            type: "function",
            function: OpenAIFunctionDefinition(from: definition),
            cacheControl: nil
        )
    }
}
