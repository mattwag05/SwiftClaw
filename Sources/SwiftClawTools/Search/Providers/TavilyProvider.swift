import Foundation

/// Tavily AI Search provider (https://tavily.com).
public struct TavilyProvider: SearchProvider {
    public let name = "tavily"
    private let apiKey: String
    private static let endpoint = "https://api.tavily.com/search"

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func search(query: String, limit: Int) async throws -> [SearchResult] {
        var request = URLRequest(url: URL(string: Self.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "api_key": apiKey,
            "query": query,
            "max_results": limit,
            "search_depth": "basic",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }

        return results.prefix(limit).compactMap { r in
            guard let title = r["title"] as? String,
                  let url = r["url"] as? String else { return nil }
            let snippet = r["content"] as? String ?? ""
            return SearchResult(title: title, url: url, snippet: snippet)
        }
    }
}
