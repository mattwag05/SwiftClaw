import Foundation

extension KeyedDecodingContainer {
    /// Decode an optional `Int` field that the model may send as either an integer or a numeric string.
    ///
    /// Qwen3.5 (and some other models) encode all parameter values as strings even when the
    /// JSON schema specifies `integer`. This helper tries `Int` first, then falls back to `String`.
    func decodeIntOrStringIfPresent(forKey key: Key) throws -> Int? {
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return i }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Int(s) }
        return nil
    }
}
