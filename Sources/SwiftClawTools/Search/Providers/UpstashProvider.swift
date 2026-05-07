import Foundation

/// Upstash Vector-backed search provider.
public struct UpstashProvider: SearchProvider {
    public let name = "upstash"
    private let url: String
    private let token: String

    public init(url: String, token: String) {
        self.url = url
        self.token = token
    }

    public func search(query: String, limit: Int) async throws -> [SearchResult] {
        var request = URLRequest(url: URL(string: "\(url)/query")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["data": query, "topK": limit, "includeMetadata": true]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return results.prefix(limit).compactMap { r in
            guard let meta = r["metadata"] as? [String: Any] else { return nil }
            let title = meta["title"] as? String ?? "Result"
            let url = meta["url"] as? String ?? ""
            let snippet = meta["snippet"] as? String ?? ""
            return SearchResult(title: title, url: url, snippet: snippet)
        }
    }
}
