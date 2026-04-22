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

    /// Decode an optional `Bool` field that the model may send as either a boolean or the string "true"/"false".
    func decodeBoolOrStringIfPresent(forKey key: Key) throws -> Bool? {
        if let b = try? decodeIfPresent(Bool.self, forKey: key) { return b }
        if let s = try? decodeIfPresent(String.self, forKey: key) {
            switch s.lowercased() {
            case "true":
                return true
            case "false":
                return false
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: key,
                    in: self,
                    debugDescription: "Expected a boolean or the string \"true\"/\"false\", but found \"\(s)\"."
                )
            }
        }
        return nil
    }
}
