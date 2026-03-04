import Foundation

/// Lightweight JSON Schema representation for tool parameter definitions.
/// Encodes to the standard JSON Schema format that LLMs expect for tool calling.
public indirect enum JSONSchema: Sendable, Equatable {
    case object(properties: [String: JSONSchema], required: [String])
    case string(description: String?)
    case integer(description: String?)
    case number(description: String?)
    case boolean(description: String?)
    case array(items: JSONSchema, description: String?)
    case enumeration(values: [String], description: String?)
}

extension JSONSchema: Encodable {
    private enum CodingKeys: String, CodingKey {
        case type, description, properties, required, items
        case `enum`
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .object(properties, required):
            try container.encode("object", forKey: .type)
            try container.encode(properties, forKey: .properties)
            if !required.isEmpty {
                try container.encode(required, forKey: .required)
            }
        case let .string(description):
            try container.encode("string", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
        case let .integer(description):
            try container.encode("integer", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
        case let .number(description):
            try container.encode("number", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
        case let .boolean(description):
            try container.encode("boolean", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
        case let .array(items, description):
            try container.encode("array", forKey: .type)
            try container.encode(items, forKey: .items)
            try container.encodeIfPresent(description, forKey: .description)
        case let .enumeration(values, description):
            try container.encode("string", forKey: .type)
            try container.encode(values, forKey: .enum)
            try container.encodeIfPresent(description, forKey: .description)
        }
    }
}

extension JSONSchema: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        // Check for enum first (it's a string type with enum values)
        if let enumValues = try container.decodeIfPresent([String].self, forKey: .enum) {
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .enumeration(values: enumValues, description: description)
            return
        }

        switch type {
        case "object":
            let properties = try container.decodeIfPresent(
                [String: JSONSchema].self, forKey: .properties) ?? [:]
            let required = try container.decodeIfPresent(
                [String].self, forKey: .required) ?? []
            self = .object(properties: properties, required: required)
        case "string":
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .string(description: description)
        case "integer":
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .integer(description: description)
        case "number":
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .number(description: description)
        case "boolean":
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .boolean(description: description)
        case "array":
            let items = try container.decode(JSONSchema.self, forKey: .items)
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .array(items: items, description: description)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown JSON Schema type: \(type)")
        }
    }
}
