import Foundation
import SwiftClawCore

/// Searches memory using hybrid semantic + keyword retrieval.
public struct MemorySearchTool: SwiftClawTool, @unchecked Sendable {
    public let name = "memory_search"
    public let description =
        "Search agent memory using semantic and keyword matching. Returns the top-K most relevant entries."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "query": .string(description: "Search query string"),
            "topK": .integer(description: "Maximum number of results to return. Defaults to 5."),
            "layer": .enumeration(
                values: ["working", "longTerm"],
                description: "Memory layer to search. Omit to search both layers."),
        ],
        required: ["query"]
    )

    public let store: any MemoryProvider

    public init(store: any MemoryProvider) {
        self.store = store
    }

    private struct Arguments: Decodable {
        let query: String
        let topK: Int?
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

        let topK = args.topK ?? 5

        let results: [ScoredMemory]
        do {
            results = try await store.search(query: args.query, layer: resolvedLayer, topK: topK)
        } catch {
            return .failure("Search failed: \(error.localizedDescription)")
        }

        guard !results.isEmpty else {
            return .success("No memories found matching '\(args.query)'.")
        }

        let lines = results.map { scored -> String in
            return "- \(scored.entry.key) (score: \(String(format: "%.2f", scored.score))): \(scored.entry.content)"
        }
        return .success(lines.joined(separator: "\n"))
    }
}
