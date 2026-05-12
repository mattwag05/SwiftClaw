import Foundation

/// Jina AI Search provider (https://jina.ai/reader).
public struct JinaProvider: SearchProvider {
    public let name = "jina"
    private let apiKey: String
    private static let endpoint = "https://s.jina.ai/"

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func search(query: String, limit: Int) async throws -> [SearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(Self.endpoint)\(encoded)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("\(limit)", forHTTPHeaderField: "X-With-Links-Summary")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["data"] as? [[String: Any]] else { return [] }

        return results.prefix(limit).compactMap { r in
            guard let title = r["title"] as? String,
                  let url = r["url"] as? String else { return nil }
            let snippet = r["description"] as? String ?? ""
            return SearchResult(title: title, url: url, snippet: snippet)
        }
    }
}
