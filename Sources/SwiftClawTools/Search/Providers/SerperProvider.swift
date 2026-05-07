import Foundation

/// Serper.dev Google Search provider (https://serper.dev).
public struct SerperProvider: SearchProvider {
    public let name = "serper"
    private let apiKey: String
    private static let endpoint = "https://google.serper.dev/search"

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func search(query: String, limit: Int) async throws -> [SearchResult] {
        var request = URLRequest(url: URL(string: Self.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        let body: [String: Any] = ["q": query, "num": limit]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let organics = json["organic"] as? [[String: Any]] else { return [] }

        return organics.prefix(limit).compactMap { r in
            guard let title = r["title"] as? String,
                  let url = r["link"] as? String else { return nil }
            let snippet = r["snippet"] as? String ?? ""
            return SearchResult(title: title, url: url, snippet: snippet)
        }
    }
}
