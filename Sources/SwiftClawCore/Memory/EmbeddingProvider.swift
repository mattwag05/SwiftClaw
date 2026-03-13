import Foundation

/// Protocol for text embedding providers.
///
/// Conforming types are actors that convert text into fixed-length float vectors.
/// `dimensions` is `nonisolated` so callers can read it without actor-hopping.
public protocol EmbeddingProvider: Actor, Sendable {
    /// The fixed dimensionality of the output embedding vectors.
    nonisolated var dimensions: Int { get }

    /// Returns a normalised embedding vector for the given text, or `nil` on failure.
    func embed(_ text: String) async -> [Float]?

    /// Returns embedding vectors for multiple texts in order.
    /// Individual elements may be `nil` if embedding failed for that input.
    func embed(texts: [String]) async -> [[Float]?]
}
