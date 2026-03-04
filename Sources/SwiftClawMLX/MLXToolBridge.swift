import Foundation
import MLXLMCommon
import SwiftClawCore
import Tokenizers

/// Converts between SwiftClaw's tool types and mlx-swift-lm's ToolSpec format.
enum MLXToolBridge {

    /// Convert a SwiftClaw `ToolDefinition` to an mlx-swift-lm `ToolSpec`.
    ///
    /// ToolSpec is `[String: any Sendable]` with structure:
    /// `{"type": "function", "function": {"name": ..., "description": ..., "parameters": {...}}}`
    static func toToolSpec(_ definition: ToolDefinition) -> ToolSpec {
        [
            "type": "function" as any Sendable,
            "function": [
                "name": definition.name,
                "description": definition.description,
                "parameters": jsonSchemaToDict(definition.parameters),
            ] as [String: any Sendable] as any Sendable,
        ]
    }

    /// Convert SwiftClaw's `JSONSchema` to a dictionary for ToolSpec.
    private static func jsonSchemaToDict(_ schema: JSONSchema) -> [String: any Sendable] {
        switch schema {
        case let .object(properties, required):
            var dict: [String: any Sendable] = ["type": "object"]
            var propsDict: [String: any Sendable] = [:]
            for (key, value) in properties {
                propsDict[key] = jsonSchemaToDict(value)
            }
            dict["properties"] = propsDict
            if !required.isEmpty {
                dict["required"] = required
            }
            return dict

        case let .string(description):
            var dict: [String: any Sendable] = ["type": "string"]
            if let desc = description { dict["description"] = desc }
            return dict

        case let .integer(description):
            var dict: [String: any Sendable] = ["type": "integer"]
            if let desc = description { dict["description"] = desc }
            return dict

        case let .number(description):
            var dict: [String: any Sendable] = ["type": "number"]
            if let desc = description { dict["description"] = desc }
            return dict

        case let .boolean(description):
            var dict: [String: any Sendable] = ["type": "boolean"]
            if let desc = description { dict["description"] = desc }
            return dict

        case let .array(items, description):
            var dict: [String: any Sendable] = ["type": "array"]
            dict["items"] = jsonSchemaToDict(items)
            if let desc = description { dict["description"] = desc }
            return dict

        case let .enumeration(values, description):
            var dict: [String: any Sendable] = ["type": "string"]
            dict["enum"] = values
            if let desc = description { dict["description"] = desc }
            return dict
        }
    }

    /// Convert SwiftClaw `Message` array to mlx-swift-lm `Chat.Message` array.
    static func toChatMessages(_ messages: [SwiftClawCore.Message]) -> [Chat.Message] {
        var result: [Chat.Message] = []
        for msg in messages {
            switch msg.role {
            case .system:
                result.append(.system(msg.content))
            case .user:
                result.append(.user(msg.content))
            case .assistant:
                // If assistant has tool calls, format them in content
                if let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
                    let toolCallsJSON = formatToolCallsForAssistant(toolCalls)
                    let content = msg.content.isEmpty ? toolCallsJSON : "\(msg.content)\n\(toolCallsJSON)"
                    result.append(.assistant(content))
                } else {
                    result.append(.assistant(msg.content))
                }
            case .tool:
                result.append(.tool(msg.content))
            }
        }
        return result
    }

    /// Format tool calls as JSON for the assistant message content.
    private static func formatToolCallsForAssistant(_ toolCalls: [ToolCallRequest]) -> String {
        let calls = toolCalls.map { call -> [String: Any] in
            [
                "name": call.name,
                "arguments": (try? JSONSerialization.jsonObject(with: Data(call.arguments.utf8))) ?? call.arguments,
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: calls, options: .fragmentsAllowed),
              let string = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return string
    }

    /// Convert an mlx-swift-lm `ToolCall` to a SwiftClaw `ToolCallRequest`.
    static func toToolCallRequest(_ toolCall: ToolCall) -> ToolCallRequest {
        let argsDict = toolCall.function.arguments.mapValues { jsonValueToAny($0) }
        let argsJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: argsDict),
           let string = String(data: data, encoding: .utf8)
        {
            argsJSON = string
        } else {
            argsJSON = "{}"
        }

        return ToolCallRequest(
            id: UUID().uuidString,
            name: toolCall.function.name,
            arguments: argsJSON
        )
    }

    /// Convert JSONValue to Any for JSONSerialization.
    private static func jsonValueToAny(_ value: JSONValue) -> Any {
        switch value {
        case .null: return NSNull()
        case let .bool(b): return b
        case let .int(i): return i
        case let .double(d): return d
        case let .string(s): return s
        case let .array(arr): return arr.map { jsonValueToAny($0) }
        case let .object(obj): return obj.mapValues { jsonValueToAny($0) }
        }
    }
}
