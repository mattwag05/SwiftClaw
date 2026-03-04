import Foundation

/// Parses Server-Sent Events line-by-line, yielding data payloads.
///
/// SSE format:
///   data: <json>\n
///   \n
///   data: [DONE]\n
struct SSEParser {
    private let decoder = JSONDecoder()

    /// Parse a single line from the SSE stream.
    /// Returns the decoded chunk if the line contains a complete data payload,
    /// nil for empty lines or non-data lines, and throws on [DONE].
    func parse(line: String) throws -> ChatCompletionChunk? {
        guard line.hasPrefix("data: ") else { return nil }
        let payload = String(line.dropFirst(6))
        if payload == "[DONE]" { throw SSEDoneError() }
        guard let data = payload.data(using: .utf8) else { return nil }
        return try decoder.decode(ChatCompletionChunk.self, from: data)
    }
}

/// Thrown when the SSE stream sends the [DONE] sentinel.
struct SSEDoneError: Error {}
