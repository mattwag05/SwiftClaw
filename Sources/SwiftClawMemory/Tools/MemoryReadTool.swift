import Foundation
import SwiftClawCore

/// Reads a memory entry by key from the specified layer (or both layers).
public struct MemoryReadTool: SwiftClawTool, @unchecked Sendable {
    public let name = "memory_read"
    public let description =
        "Read a memory entry by key. If layer is omitted, searches working memory first then long-term."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "key": .string(description: "Memory key identifier to look up"),
            "layer": .enumeration(
                values: ["working", "longTerm"],
                description: "Memory layer to search. Omit to search both (working first)."),
        ],
        required: ["key"]
    )

    public let store: any MemoryProvider

    public init(store: any MemoryProvider) {
        self.store = store
    }

    private struct Arguments: Decodable {
        let key: String
        let layer: String?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONDecoder().decode(Arguments.self, from: data) else {
            return .failure("Invalid arguments")
        }

        let resolvedLayer: MemoryLayer?
        if let layerString = args.layer {
            guard let l = MemoryLayer(rawValue: layerString) else {
                return .failure("Invalid layer '\(layerString)'. Must be 'working' or 'longTerm'.")
            }
            resolvedLayer = l
        } else {
            resolvedLayer = nil
        }

        guard let entry = await store.get(args.key, layer: resolvedLayer) else {
            return .success("No memory found for key '\(args.key)'.")
        }

        return .success(entry.content)
    }
}
