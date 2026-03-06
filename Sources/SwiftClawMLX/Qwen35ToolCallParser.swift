import Foundation
import SwiftClawCore

/// Fallback parser for Qwen3.5 XML-function-tagged tool call blocks.
///
/// Qwen3.5 embeds tool calls in accumulated generation text as:
/// ```
/// <tool_call>
/// <function=name>
/// <parameter=key>
/// value
/// </parameter>
/// </function>
/// </tool_call>
/// ```
///
/// This parser is invoked by `MLXBackend` when mlx-swift-lm does not natively
/// emit `.toolCall` events for this format. If upstream adds support, the
/// fallback is a no-op (collectedToolCalls will be non-empty before it runs).
enum Qwen35ToolCallParser {
    struct ParseResult {
        let toolCalls: [ToolCallRequest]
        /// Input text with all `<tool_call>...</tool_call>` blocks removed.
        let remainingText: String
    }

    /// Parse all tool call blocks from accumulated generation text.
    ///
    /// Handles two formats:
    /// 1. `<tool_call>...<function=name>...</function>...</tool_call>` (full template format)
    /// 2. `<function=name>...<parameter=key>value</parameter>...</function>` (bare, without outer tag)
    static func parse(text: String) -> ParseResult {
        var toolCalls: [ToolCallRequest] = []
        var result = ""
        var remaining = text

        // First pass: extract <tool_call>...</tool_call> blocks
        let outerStart = "<tool_call>"
        let outerEnd = "</tool_call>"
        var pass1 = ""
        var rem = remaining
        while let blockStart = rem.range(of: outerStart),
              let blockEnd = rem.range(of: outerEnd),
              blockStart.upperBound <= blockEnd.lowerBound
        {
            pass1 += rem[rem.startIndex..<blockStart.lowerBound]
            let inner = String(rem[blockStart.upperBound..<blockEnd.lowerBound])
            if let call = parseBlock(inner) {
                toolCalls.append(call)
            }
            rem = String(rem[blockEnd.upperBound...])
        }
        pass1 += rem
        remaining = pass1

        // Second pass: extract bare <function=name>...</function> blocks
        let funcStart = "<function="
        let funcEnd = "</function>"
        var pass2 = ""
        rem = remaining
        while let blockStart = rem.range(of: funcStart),
              let blockEnd = rem.range(of: funcEnd),
              blockStart.upperBound <= blockEnd.lowerBound
        {
            pass2 += rem[rem.startIndex..<blockStart.lowerBound]
            // Treat as if inside a <tool_call> block
            let inner = String(rem[blockStart.lowerBound..<blockEnd.upperBound])
            if let call = parseBlock(inner) {
                toolCalls.append(call)
            }
            rem = String(rem[blockEnd.upperBound...])
        }
        pass2 += rem
        result = pass2

        return ParseResult(toolCalls: toolCalls, remainingText: result)
    }

    /// Parse the inner content of a single `<tool_call>` block.
    ///
    /// Expects: `<function=name>\n<parameter=key>\nvalue\n</parameter>\n</function>`
    static func parseBlock(_ content: String) -> ToolCallRequest? {
        guard let funcStart = content.range(of: "<function=") else { return nil }
        let afterFuncEq = content[funcStart.upperBound...]

        guard let funcNameEnd = afterFuncEq.firstIndex(where: { $0 == ">" || $0 == "\n" }) else {
            return nil
        }
        let funcName = String(afterFuncEq[..<funcNameEnd]).trimmingCharacters(in: .whitespaces)
        guard !funcName.isEmpty else { return nil }

        let paramSectionStart: String.Index
        if afterFuncEq[funcNameEnd] == ">" {
            paramSectionStart = afterFuncEq.index(after: funcNameEnd)
        } else {
            paramSectionStart = funcNameEnd
        }

        guard let funcEnd = content.range(of: "</function>"),
              funcEnd.lowerBound >= paramSectionStart else { return nil }
        let paramSection = String(content[paramSectionStart..<funcEnd.lowerBound])

        var arguments: [String: String] = [:]
        var remaining = paramSection

        while let paramTagStart = remaining.range(of: "<parameter=") {
            let afterEq = remaining[paramTagStart.upperBound...]
            guard let paramNameEnd = afterEq.firstIndex(where: { $0 == ">" || $0 == "\n" }) else {
                break
            }
            let paramName = String(afterEq[..<paramNameEnd]).trimmingCharacters(in: .whitespaces)

            let valueStart: String.Index
            if afterEq[paramNameEnd] == ">" {
                valueStart = afterEq.index(after: paramNameEnd)
            } else {
                valueStart = paramNameEnd
            }
            let afterParamTag = remaining[valueStart...]

            guard let paramEnd = afterParamTag.range(of: "</parameter>") else { break }
            var paramValue = String(afterParamTag[..<paramEnd.lowerBound])

            // Trim leading/trailing newlines (matching mlx-lm Python behavior)
            if paramValue.hasPrefix("\n") { paramValue = String(paramValue.dropFirst()) }
            if paramValue.hasSuffix("\n") { paramValue = String(paramValue.dropLast()) }

            arguments[paramName] = paramValue
            remaining = String(afterParamTag[paramEnd.upperBound...])
        }

        let argsJSON: String
        if arguments.isEmpty {
            argsJSON = "{}"
        } else if let data = try? JSONSerialization.data(withJSONObject: arguments, options: .withoutEscapingSlashes),
                  let jsonStr = String(data: data, encoding: .utf8) {
            argsJSON = jsonStr
        } else {
            argsJSON = "{}"
        }

        return ToolCallRequest(id: UUID().uuidString, name: funcName, arguments: argsJSON)
    }
}
