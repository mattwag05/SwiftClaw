import Foundation

/// SearXNG self-hosted search provider (https://searxng.org).
public struct SearXNGProvider: SearchProvider {
    public let name = "searxng"
    private let baseURL: String

    public init(baseURL: String) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
    }

    public func search(query: String, limit: Int) async throws -> [SearchResult] {
        guard var comps = URLComponents(string: "\(baseURL)/search") else {
            throw URLError(.badURL)
        }
        comps.queryItems = [
            .init(name: "q", value: query),
            .init(name: "format", value: "json"),
            .init(name: "engines", value: "google,bing"),
        ]
        guard let searchURL = comps.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: searchURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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
