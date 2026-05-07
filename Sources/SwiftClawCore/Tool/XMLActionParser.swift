import Foundation

/// A parsed action emitted by the model using the XML tool protocol.
public struct ParsedXMLAction: Sendable {
    public let name: String
    /// Tool arguments encoded as a JSON object string (same shape as ToolCallRequest.arguments).
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

/// Pure, stateless parser for model-emitted XML action blocks.
///
/// Models configured with the XML tool protocol emit tool calls as:
///   `<action name="tool_name"><param1>value1</param1>...</action>`
///
/// The parser finds complete blocks in accumulated streaming text, converts
/// their parameters to a JSON object string, and identifies the safe-emit
/// boundary — the longest prefix of incoming text that cannot possibly be
/// the start of an `<action` tag.
public struct XMLActionParser: Sendable {
    public init() {}

    // MARK: - Action detection

    /// Finds the first complete action block in `text`.
    ///
    /// Returns `(before, action, after)` where `before` is text preceding the
    /// block and `after` follows it. Returns `nil` if no complete block exists.
    public func findAction(in text: String) -> (before: String, action: ParsedXMLAction, after: String)? {
        guard let openRange = text.range(of: "<action") else { return nil }
        guard let closeRange = text.range(of: "</action>") else { return nil }
        guard openRange.lowerBound < closeRange.upperBound else { return nil }

        let before = String(text[..<openRange.lowerBound])
        let block = String(text[openRange.lowerBound..<closeRange.upperBound])
        let after = String(text[closeRange.upperBound...])

        guard let action = parseBlock(block) else { return nil }
        return (before, action, after)
    }

    /// Returns `(emit, buffer)` — the safe-to-emit text prefix and a remainder
    /// that must be held until more stream chunks arrive.
    ///
    /// "Safe" means the prefix cannot possibly be the start of `<action`.
    /// If the text already contains `<action`, everything before it is safe.
    /// Otherwise the longest suffix that is also a prefix of `<action` is buffered.
    public func safePrefix(of text: String) -> (emit: String, buffer: String) {
        let sentinel = "<action"

        // Full sentinel present: everything before it is safe.
        if let range = text.range(of: sentinel) {
            return (String(text[..<range.lowerBound]), String(text[range.lowerBound...]))
        }

        // Find the longest suffix of `text` that matches a prefix of sentinel.
        let sentinelChars = Array(sentinel)
        let textChars = Array(text)
        var bufferCount = 0
        for len in stride(from: min(sentinelChars.count, textChars.count), through: 1, by: -1) {
            if textChars.suffix(len).elementsEqual(sentinelChars.prefix(len)) {
                bufferCount = len
                break
            }
        }

        if bufferCount == 0 { return (text, "") }
        let splitIdx = text.index(text.endIndex, offsetBy: -bufferCount)
        return (String(text[..<splitIdx]), String(text[splitIdx...]))
    }

    // MARK: - Content cleaning

    /// Strips markdown code fences from file content the model wrapped for readability.
    ///
    /// Handles ` ```lang\n...\n``` ` blocks by removing the opening and closing fence
    /// lines, returning only the inner content.
    public func cleanFileContent(_ content: String) -> String {
        var lines = content.components(separatedBy: "\n")
        if let first = lines.first, first.hasPrefix("```") {
            lines.removeFirst()
        }
        if lines.last == "```" {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func parseBlock(_ block: String) -> ParsedXMLAction? {
        // Extract name from <action name="tool"> or <action name='tool'>
        guard let nameAttrRange = block.range(of: #"name=["'][^"']+["']"#, options: .regularExpression) else {
            return nil
        }
        let attrText = String(block[nameAttrRange])
        // Strip the `name=` prefix and surrounding quotes
        let valuePattern = #"["']([^"']+)["']"#
        guard let valueRange = attrText.range(of: valuePattern, options: .regularExpression) else {
            return nil
        }
        var name = String(attrText[valueRange])
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !name.isEmpty else { return nil }

        // Body lives between the first `>` and `</action>`
        guard let openTagClose = block.firstIndex(of: ">"),
              let actionClose = block.range(of: "</action>") else { return nil }
        let bodyStart = block.index(after: openTagClose)
        guard bodyStart <= actionClose.lowerBound else { return nil }
        let body = String(block[bodyStart..<actionClose.lowerBound])

        let params = parseParams(from: body)
        return ParsedXMLAction(name: name, arguments: encodeJSON(params))
    }

    /// Parses `<key>value</key>` child elements from an action body.
    private func parseParams(from body: String) -> [String: String] {
        var params: [String: String] = [:]
        guard let regex = try? NSRegularExpression(
            pattern: #"<([a-zA-Z][a-zA-Z0-9_-]*)>([\s\S]*?)</\1>"#
        ) else { return params }

        let ns = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            guard match.numberOfRanges == 3 else { continue }
            let keyRange = match.range(at: 1)
            let valRange = match.range(at: 2)
            guard keyRange.location != NSNotFound, valRange.location != NSNotFound else { continue }
            params[ns.substring(with: keyRange)] = ns.substring(with: valRange)
        }
        return params
    }

    private func encodeJSON(_ dict: [String: String]) -> String {
        guard !dict.isEmpty else { return "{}" }
        guard let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: .withoutEscapingSlashes
        ), let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}
