/// Formats tool definitions into an XML action instruction block for injection
/// into the system prompt of models using the XML tool protocol.
///
/// The output is appended to the system message so the model knows:
/// - Which tools are available and what their parameters mean
/// - Exactly how to emit `<action>` blocks
public struct XMLActionFormatter: Sendable {
    public init() {}

    /// Returns the XML tool-use instruction block to append to the system prompt.
    /// Returns an empty string when `tools` is empty.
    public func formatToolBlock(tools: [ToolDefinition]) -> String {
        guard !tools.isEmpty else { return "" }

        var out = """

        ## Tool Use

        Call tools by emitting XML action blocks in this exact format:

        <action name="tool_name">
        <parameter_name>parameter_value</parameter_name>
        </action>

        Rules:
        - Emit ONE action block at a time. After emitting an action, stop — do not write any more text until you receive the result.
        - Parameter values are plain text. Do not use XML entities or extra encoding.
        - Omit optional parameters when not needed.

        ## Available Tools

        """

        for tool in tools {
            out += formatTool(tool)
            out += "\n"
        }

        return out
    }

    // MARK: - Private

    private func formatTool(_ tool: ToolDefinition) -> String {
        var text = "### \(tool.name)\n\(tool.description)\n"

        guard case let .object(properties, required) = tool.parameters, !properties.isEmpty else {
            text += "No parameters.\n"
            return text
        }

        text += "Parameters:\n"
        let sortedProps = properties.sorted { $0.key < $1.key }
        for (name, schema) in sortedProps {
            let req = required.contains(name) ? " (required)" : " (optional)"
            text += "- `\(name)`\(req): \(schemaDescription(schema))\n"
        }

        // Show a minimal example using required parameters
        let requiredProps = sortedProps.filter { required.contains($0.key) }
        let exampleProps = requiredProps.isEmpty ? Array(sortedProps.prefix(2)) : Array(requiredProps.prefix(2))
        if !exampleProps.isEmpty {
            text += "Example:\n```\n<action name=\"\(tool.name)\">\n"
            for (name, _) in exampleProps {
                text += "<\(name)>...\(name) value...</\(name)>\n"
            }
            text += "</action>\n```\n"
        }

        return text
    }

    private func schemaDescription(_ schema: JSONSchema) -> String {
        switch schema {
        case let .string(desc):           return "string\(desc.map { " — \($0)" } ?? "")"
        case let .integer(desc):          return "integer\(desc.map { " — \($0)" } ?? "")"
        case let .number(desc):           return "number\(desc.map { " — \($0)" } ?? "")"
        case let .boolean(desc):          return "boolean\(desc.map { " — \($0)" } ?? "")"
        case let .array(_, desc):         return "array\(desc.map { " — \($0)" } ?? "")"
        case let .enumeration(vals, desc):
            return "enum(\(vals.joined(separator: "|")))\(desc.map { " — \($0)" } ?? "")"
        case .object:                     return "object"
        }
    }
}
