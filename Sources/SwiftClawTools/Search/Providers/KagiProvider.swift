import Foundation

/// Kagi Search API provider (https://kagi.com/api).
public struct KagiProvider: SearchProvider {
    public let name = "kagi"
    private let apiKey: String
    private static let endpoint = "https://kagi.com/api/v0/search"

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func search(query: String, limit: Int) async throws -> [SearchResult] {
        guard var comps = URLComponents(string: Self.endpoint) else {
            throw URLError(.badURL)
        }
        comps.queryItems = [
            .init(name: "q", value: query),
            .init(name: "limit", value: "\(limit)"),
        ]
        guard let searchURL = comps.url else { throw URLError(.badURL) }
        var request = URLRequest(url: searchURL)
        request.setValue("Bot \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["data"] as? [[String: Any]] else { return [] }

        return results.prefix(limit).compactMap { r in
            guard let title = r["title"] as? String,
                  let url = r["url"] as? String else { return nil }
            let snippet = r["snippet"] as? String ?? ""
            return SearchResult(title: title, url: url, snippet: snippet)
        }
    }
}
