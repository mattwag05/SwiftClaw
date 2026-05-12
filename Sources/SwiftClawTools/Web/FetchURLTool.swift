import Foundation
import SwiftClawCore

/// Fetches a URL and returns cleaned text content.
///
/// Strips `<script>`, `<style>`, and HTML tags, then truncates to 8 000 characters.
/// Only HTTP/HTTPS URLs are accepted.
public struct FetchURLTool: SwiftClawTool {
    public let name = "fetch_url"
    public let requiresConfirmation = false
    public let description = "Fetch a URL and return the cleaned text content (HTTP/HTTPS only, max 8000 chars)."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "url": .string(description: "HTTP or HTTPS URL to fetch"),
        ],
        required: ["url"]
    )

    private static let maxChars = 8_000

    public init() {}

    private struct Arguments: Decodable {
        var url: String
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        guard let url = URL(string: args.url),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return .failure("Only HTTP/HTTPS URLs are supported")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            return .failure("Fetch failed: \(error.localizedDescription)")
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return .failure("HTTP \(http.statusCode) from \(args.url)")
        }

        guard var text = String(data: data, encoding: .utf8) ??
              String(data: data, encoding: .isoLatin1) else {
            return .failure("Response is not valid text")
        }

        text = stripScriptStyle(text)
        text = stripTags(text)
        text = collapseWhitespace(text)

        if text.count > Self.maxChars {
            text = String(text.prefix(Self.maxChars)) + "\n\n[Truncated at 8000 chars]"
        }

        return .success(text.isEmpty ? "(empty response)" : text)
    }

    private func stripScriptStyle(_ html: String) -> String {
        var result = html
        for tag in ["script", "style"] {
            let pattern = "(?s)<\(tag)[^>]*>.*?</\(tag)>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }
        return result
    }

    private func stripTags(_ html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) else {
            return html
        }
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(html.startIndex..., in: html),
            withTemplate: " "
        )
    }

    private func collapseWhitespace(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }
}
