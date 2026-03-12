import Foundation
import SwiftClawCore

/// Deletes a memory entry from the specified layer. Requires user confirmation.
public struct MemoryDeleteTool: SwiftClawTool, @unchecked Sendable {
    public let name = "memory_delete"
    public let description =
        "Delete a memory entry by key from the specified memory layer. This action requires confirmation."

    public let requiresConfirmation: Bool = true

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "key": .string(description: "Memory key identifier to delete"),
            "layer": .enumeration(
                values: ["working", "longTerm"],
                description: "Memory layer to delete from: 'working' or 'longTerm'"),
        ],
        required: ["key", "layer"]
    )

    public let store: any MemoryProvider

    public init(store: any MemoryProvider) {
        self.store = store
    }

    private struct Arguments: Decodable {
        let key: String
        let layer: String
    }

    public func execute(arguments: String) async throws -> ToolResult {
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONDecoder().decode(Arguments.self, from: data) else {
            return .failure("Invalid arguments")
        }

        guard let resolvedLayer = MemoryLayer(rawValue: args.layer) else {
            return .failure("Invalid layer '\(args.layer)'. Must be 'working' or 'longTerm'.")
        }

        do {
            try await store.delete(args.key, layer: resolvedLayer)
        } catch {
            return .failure("Failed to delete memory: \(error.localizedDescription)")
        }

        return .success("Deleted '\(args.key)' from \(args.layer) memory.")
    }
}
