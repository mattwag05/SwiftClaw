import Foundation
import SwiftClawCore

/// Writes a memory entry to the specified layer of the memory store.
public struct MemoryWriteTool: SwiftClawTool, @unchecked Sendable {
    public let name = "memory_write"
    public let description =
        "Store a piece of information in agent memory. Use 'working' for session-scoped data and 'longTerm' for persistent knowledge."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "key": .string(description: "Memory key identifier — short, descriptive, lowercase-hyphenated"),
            "content": .string(description: "Content to store in memory"),
            "layer": .enumeration(
                values: ["working", "longTerm"],
                description: "Memory layer: 'working' (session-scoped) or 'longTerm' (persistent). Defaults to 'working'."),
        ],
        required: ["key", "content"]
    )

    public let store: any MemoryProvider

    public init(store: any MemoryProvider) {
        self.store = store
    }

    private struct Arguments: Decodable {
        let key: String
        let content: String
        let layer: String?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONDecoder().decode(Arguments.self, from: data) else {
            return .failure("Invalid arguments")
        }

        let layerString = args.layer ?? "working"
        guard let resolvedLayer = MemoryLayer(rawValue: layerString) else {
            return .failure("Invalid layer '\(layerString)'. Must be 'working' or 'longTerm'.")
        }

        let entry = MemoryEntry(
            key: args.key,
            content: args.content,
            updatedAt: Date(),
            source: "agent"
        )

        do {
            try await store.set(args.key, entry: entry, layer: resolvedLayer)
        } catch {
            return .failure("Failed to store memory: \(error.localizedDescription)")
        }

        return .success("Stored '\(args.key)' to \(layerString) memory.")
    }
}
