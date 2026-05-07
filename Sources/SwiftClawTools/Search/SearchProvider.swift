import Foundation

/// A single web search result.
public struct SearchResult: Sendable {
    public let title: String
    public let url: String
    public let snippet: String

    public init(title: String, url: String, snippet: String) {
        self.title = title
        self.url = url
        self.snippet = snippet
    }
}

/// Protocol for pluggable web search backends.
public protocol SearchProvider: Sendable {
    var name: String { get }
    func search(query: String, limit: Int) async throws -> [SearchResult]
}

/// A null provider used when no search API is configured.
public struct NullSearchProvider: SearchProvider {
    public let name = "none"
    public init() {}
    public func search(query: String, limit: Int) async throws -> [SearchResult] { [] }
}
