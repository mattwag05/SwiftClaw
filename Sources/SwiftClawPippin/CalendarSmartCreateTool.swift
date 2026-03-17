import Foundation
import SwiftClawCore

/// Creates a calendar event from natural language via `pippin calendar smart-create`.
public struct CalendarSmartCreateTool: SwiftClawTool {
    public let name = "calendar_smart_create"
    public let requiresConfirmation = true
    public let description =
        "Create an Apple Calendar event from a natural language description. " +
        "Example: 'coffee with Alice tomorrow at 3pm for 30 minutes'. " +
        "Uses Ollama by default; pass provider='claude' with an api_key for Claude."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "description": .string(description: "Natural language description of the event (required)."),
            "calendar":    .string(description: "Calendar name to create the event in (optional)."),
            "dry_run":     .boolean(description: "If true, print parsed event JSON without creating it."),
            "provider":    .string(description: "AI provider: ollama (default) or claude."),
            "api_key":     .string(description: "API key for Claude provider (required if provider=claude)."),
        ],
        required: ["description"]
    )

    private let runner: PippinRunner

    public init(runner: PippinRunner) {
        self.runner = runner
    }

    private struct Arguments: Decodable {
        var description: String
        var calendar: String?
        var dryRun: Bool?
        var provider: String?
        var apiKey: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            description = try c.decode(String.self, forKey: .description)
            calendar    = try? c.decodeIfPresent(String.self, forKey: .calendar)
            provider    = try? c.decodeIfPresent(String.self, forKey: .provider)
            apiKey      = try? c.decodeIfPresent(String.self, forKey: .apiKey)
            if let b = try? c.decodeIfPresent(Bool.self, forKey: .dryRun) {
                dryRun = b
            } else if let s = try? c.decodeIfPresent(String.self, forKey: .dryRun) {
                dryRun = s.lowercased() == "true"
            } else { dryRun = nil }
        }

        enum CodingKeys: String, CodingKey {
            case description, calendar, provider
            case dryRun  = "dry_run"
            case apiKey  = "api_key"
        }
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        // smart-create takes description as a positional argument, not a flag
        var argv: [String] = ["smart-create", args.description]
        if let calendar  = args.calendar  { argv += ["--calendar", calendar] }
        if let provider  = args.provider  { argv += ["--provider", provider] }
        if let apiKey    = args.apiKey    { argv += ["--api-key", apiKey] }
        if args.dryRun == true            { argv.append("--dry-run") }

        switch await runner.run(subcommand: "calendar", arguments: argv, timeout: 60) {
        case let .success(output): return .success(output)
        case let .failure(error):  return .failure(error.localizedDescription)
        }
    }
}
