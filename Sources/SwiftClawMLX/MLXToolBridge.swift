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
                // Use raw content — it already contains the <function=name> call when
                // the text-injection path is active. Don't append JSON duplicates.
                result.append(.assistant(msg.content))
            case .tool:
                result.append(.tool(msg.content))
            }
        }
        return result
    }

    /// Inject tool descriptions as text into the system message.
    ///
    /// Used when the template's built-in tool mechanism is unavailable or broken.
    /// Appends a "# Available Tools" section to the system message and instructs
    /// the model to emit `<tool_call>` blocks. The fallback parser (`Qwen35ToolCallParser`)
    /// then extracts them from the generated text.
    static func injectToolsIntoSystemMessage(
        _ messages: [Chat.Message],
        tools: [ToolDefinition]
    ) -> [Chat.Message] {
        let toolBlock = buildToolBlock(tools)

        var result = messages
        if let first = messages.first, first.role == .system {
            result[0] = Chat.Message(role: .system, content: first.content + "\n\n" + toolBlock)
        } else {
            result.insert(Chat.Message(role: .system, content: toolBlock), at: 0)
        }
        return result
    }

    /// Build the tool-call instruction block that gets appended to the system message.
    private static func buildToolBlock(_ tools: [ToolDefinition]) -> String {
        // Note: <tool_call> tag in system message triggers EOS-after-think in Qwen3.5-4bit.
        // Describe functions with parameter info; model emits <function=NAME> XML naturally.
        let funcList = tools.map { t -> String in
            var lines = ["- \(t.name): \(t.description)"]
            if case let .object(props, required) = t.parameters, !props.isEmpty {
                for (k, schema) in props.sorted(by: { $0.key < $1.key }) {
                    let req = required.contains(k) ? " (required)" : ""
                    lines.append("    \(k)\(req): \(schemaDescription(schema))")
                }
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n")
        return """
            Call functions using this format:
            <function=NAME>
            <parameter=key>value</parameter>
            </function>

            Functions:
            \(funcList)
            """
    }

    private static func schemaDescription(_ schema: JSONSchema) -> String {
        switch schema {
        case let .string(desc): return "string\(desc.map { " — \($0)" } ?? "")"
        case let .integer(desc): return "integer\(desc.map { " — \($0)" } ?? "")"
        case let .number(desc): return "number\(desc.map { " — \($0)" } ?? "")"
        case let .boolean(desc): return "boolean\(desc.map { " — \($0)" } ?? "")"
        case let .array(_, desc): return "array\(desc.map { " — \($0)" } ?? "")"
        case let .enumeration(vals, desc): return "enum(\(vals.joined(separator: "|")))\(desc.map { " — \($0)" } ?? "")"
        case .object: return "object"
        }
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
