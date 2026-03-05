import Foundation
import SwiftClawCore

/// Returns the current date and time.
public struct DateTimeTool: SwiftClawTool {
    public let name = "date_time"
    public let description =
        "Get the current date and time. Optionally specify a timezone (e.g. 'America/New_York') and a date format string."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "timezone": .string(
                description: "IANA timezone identifier (e.g. 'UTC', 'America/New_York'). Defaults to system timezone."),
            "format": .string(
                description: "DateFormatter format string (e.g. 'yyyy-MM-dd HH:mm:ss'). Defaults to ISO 8601."),
        ],
        required: []
    )

    public init() {}

    private struct Arguments: Decodable {
        var timezone: String?
        var format: String?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))

        let formatter = DateFormatter()
        if let tzName = args.timezone {
            guard let tz = TimeZone(identifier: tzName) else {
                return .failure("Unknown timezone: '\(tzName)'")
            }
            formatter.timeZone = tz
        }

        formatter.dateFormat = args.format ?? "yyyy-MM-dd'T'HH:mm:ssXXXXX"

        let result = formatter.string(from: Date())
        let tzName = formatter.timeZone.identifier
        return .success("\(result) (\(tzName))")
    }
}
