import Foundation
import SwiftClawCore

/// Lists calendar events via `pippin calendar events`.
public struct CalendarEventsTool: SwiftClawTool {
    public let name = "calendar_events"
    public let description =
        "List Apple Calendar events for a date range. Defaults to today. " +
        "Use the 'range' parameter for convenient shorthands (today, week, month) or " +
        "supply explicit 'from'/'to' ISO 8601 dates."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "range":         .string(description: "Shorthand range: today, week, or month. Overrides from/to."),
            "from":          .string(description: "Start date in YYYY-MM-DD or ISO 8601 format."),
            "to":            .string(description: "End date in YYYY-MM-DD or ISO 8601 format."),
            "calendar_name": .string(description: "Calendar name to filter events (case-insensitive)."),
            "limit":         .integer(description: "Maximum number of events (default: 50)."),
        ],
        required: []
    )

    private let runner: PippinRunner

    public init(runner: PippinRunner) {
        self.runner = runner
    }

    private struct Arguments: Decodable {
        var range: String?
        var from: String?
        var to: String?
        var calendarName: String?
        var limit: Int?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            range        = try? c.decodeIfPresent(String.self, forKey: .range)
            from         = try? c.decodeIfPresent(String.self, forKey: .from)
            to           = try? c.decodeIfPresent(String.self, forKey: .to)
            calendarName = try? c.decodeIfPresent(String.self, forKey: .calendarName)
            if let i = try? c.decodeIfPresent(Int.self, forKey: .limit) {
                limit = i
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .limit) {
                limit = Int(s)
            } else { limit = nil }
        }

        enum CodingKeys: String, CodingKey {
            case range, from, to, limit
            case calendarName = "calendar_name"
        }
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        var argv: [String] = ["events"]
        if let range = args.range          { argv += ["--range", range] }
        if let from = args.from            { argv += ["--from", from] }
        if let to = args.to                { argv += ["--to", to] }
        if let name = args.calendarName    { argv += ["--calendar-name", name] }
        if let limit = args.limit          { argv += ["--limit", String(limit)] }

        switch await runner.run(subcommand: "calendar", arguments: argv) {
        case let .success(output): return .success(output)
        case let .failure(error):  return .failure(error.localizedDescription)
        }
    }
}
