import Foundation
import SwiftClawCore

/// Tool that fetches the full markdown body of a named skill on demand.
public struct SkillLoadTool: SwiftClawTool {
    public let name = "skill_load"
    public let description =
        "Fetch the full instructions for a skill by name. Use this when the user's request matches a listed skill."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "name": .string(description: "Name of the skill to load."),
        ],
        required: ["name"]
    )

    private let store: SkillStore

    public init(store: SkillStore) {
        self.store = store
    }

    private struct Args: Decodable {
        let name: String
    }

    public func execute(arguments: String) async throws -> ToolResult {
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONDecoder().decode(Args.self, from: data)
        else {
            return .failure("skill_load requires a 'name' argument")
        }
        do {
            let body = try await store.load(name: args.name)
            return .success(body)
        } catch let SkillError.notFound(n) {
            let available = await store.list().map(\.name).joined(separator: ", ")
            return .failure("Skill '\(n)' not found. Available: \(available.isEmpty ? "(none)" : available)")
        }
    }
}
