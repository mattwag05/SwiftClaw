import Foundation
import SwiftClawCore

// MARK: - Request

struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let tools: [OpenAIToolDefinition]?
    let stream: Bool
    let temperature: Float
    let maxTokens: Int
    let topP: Float?

    enum CodingKeys: String, CodingKey {
        case model, messages, tools, stream, temperature, topP = "top_p"
        case maxTokens = "max_tokens"
    }
}

struct OpenAIMessage: Encodable {
    let role: String
    let content: String?
    let toolCalls: [OpenAIToolCall]?
    let toolCallId: String?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
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

struct ChatCompletionChunk: Decodable {
    let choices: [ChunkChoice]
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
            self.init(role: "system", content: message.content, toolCalls: nil, toolCallId: nil)
        case .user:
            self.init(role: "user", content: message.content, toolCalls: nil, toolCallId: nil)
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
            // OpenAI requires content to be omitted (not empty string) when tool_calls present
            let content: String? = (message.toolCalls?.isEmpty == false) ? nil : message.content
            self.init(role: "assistant", content: content, toolCalls: calls, toolCallId: nil)
        case .tool:
            self.init(role: "tool", content: message.content, toolCalls: nil, toolCallId: message.toolCallId)
        }
    }
}

extension OpenAIToolDefinition {
    init(from definition: ToolDefinition) {
        self.init(
            type: "function",
            function: OpenAIFunctionDefinition(from: definition)
        )
    }
}
