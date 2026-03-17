import Foundation
import SwiftClawCore

/// Creates a calendar event via `pippin calendar create`.
public struct CalendarCreateTool: SwiftClawTool {
    public let name = "calendar_create"
    public let requiresConfirmation = true
    public let description =
        "Create a new Apple Calendar event. " +
        "Requires title and start date/time (YYYY-MM-DD or ISO 8601). " +
        "End defaults to start + 1 hour if omitted."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "title":    .string(description: "Event title (required)."),
            "start":    .string(description: "Start date/time: YYYY-MM-DD or ISO 8601 (required)."),
            "end":      .string(description: "End date/time (default: start + 1 hour)."),
            "calendar": .string(description: "Calendar name (default: system default calendar)."),
            "location": .string(description: "Event location."),
            "notes":    .string(description: "Event notes."),
            "all_day":  .boolean(description: "Create as an all-day event."),
            "alert":    .string(description: "Alert before event, e.g. '15m', '1h', '2d'."),
        ],
        required: ["title", "start"]
    )

    private let runner: PippinRunner

    public init(runner: PippinRunner) {
        self.runner = runner
    }

    private struct Arguments: Decodable {
        var title: String
        var start: String
        var end: String?
        var calendar: String?
        var location: String?
        var notes: String?
        var allDay: Bool?
        var alert: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title    = try c.decode(String.self, forKey: .title)
            start    = try c.decode(String.self, forKey: .start)
            end      = try? c.decodeIfPresent(String.self, forKey: .end)
            calendar = try? c.decodeIfPresent(String.self, forKey: .calendar)
            location = try? c.decodeIfPresent(String.self, forKey: .location)
            notes    = try? c.decodeIfPresent(String.self, forKey: .notes)
            alert    = try? c.decodeIfPresent(String.self, forKey: .alert)
            if let b = try? c.decodeIfPresent(Bool.self, forKey: .allDay) {
                allDay = b
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .allDay) {
                allDay = s.lowercased() == "true"
            } else { allDay = nil }
        }

        enum CodingKeys: String, CodingKey {
            case title, start, end, calendar, location, notes, alert
            case allDay = "all_day"
        }
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        var argv: [String] = ["create", "--title", args.title, "--start", args.start]
        if let end      = args.end      { argv += ["--end", end] }
        if let calendar = args.calendar { argv += ["--calendar", calendar] }
        if let location = args.location { argv += ["--location", location] }
        if let notes    = args.notes    { argv += ["--notes", notes] }
        if let alert    = args.alert    { argv += ["--alert", alert] }
        if args.allDay == true          { argv.append("--all-day") }

        switch await runner.run(subcommand: "calendar", arguments: argv) {
        case let .success(output): return .success(output)
        case let .failure(error):  return .failure(error.localizedDescription)
        }
    }
}
