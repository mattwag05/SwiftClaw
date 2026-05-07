import Foundation
import SwiftClawCore

/// Runs a web search via the configured `SearchProvider`.
/// Returns a formatted list of results (title, URL, snippet). Returns empty if no provider configured.
public struct WebSearchTool: SwiftClawTool {
    public let name = "web_search"
    public let requiresConfirmation = false
    public let description = "Search the web and return relevant results."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "query": .string(description: "Search query"),
            "limit": .integer(description: "Maximum number of results (default 5, max 10)"),
        ],
        required: ["query"]
    )

    private let provider: any SearchProvider

    public init(provider: any SearchProvider = NullSearchProvider()) {
        self.provider = provider
    }

    private struct Arguments: Decodable {
        var query: String
        var limit: Int?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        let limit = min(args.limit ?? 5, 10)

        if provider.name == "none" {
            return .success("No web search provider configured. Set one in Settings → Tools.")
        }

        let results: [SearchResult]
        do {
            results = try await provider.search(query: args.query, limit: limit)
        } catch {
            return .failure("Search failed: \(error.localizedDescription)")
        }

        if results.isEmpty {
            return .success("No results found for: \(args.query)")
        }

        let formatted = results.enumerated().map { i, r in
            "[\(i + 1)] \(r.title)\n\(r.url)\n\(r.snippet)"
        }.joined(separator: "\n\n")
        return .success(formatted)
    }
}
