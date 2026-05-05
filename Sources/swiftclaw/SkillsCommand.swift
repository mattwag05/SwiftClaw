import ArgumentParser
import Foundation
import SwiftClawCore
import SwiftClawSkills

struct SkillsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skills",
        abstract: "List and inspect available skills.",
        subcommands: [ListCommand.self, ShowCommand.self]
    )

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all available skills with their descriptions."
        )

        @Option(name: .long, help: "Path to skills directory (default: ~/.swiftclaw/skills).")
        var directory: String?

        func run() async throws {
            let dir = directory.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            let store = SkillStore(directory: dir)
            let skills = await store.list()
            if skills.isEmpty {
                let path = dir?.path ?? SkillStore.defaultDirectory().path
                print("No skills found in \(path)")
                return
            }
            for skill in skills {
                print("\(skill.name): \(skill.description)")
                if !skill.triggers.isEmpty {
                    print("  triggers: \(skill.triggers.joined(separator: ", "))")
                }
            }
        }
    }

    struct ShowCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Print the full body of a skill."
        )

        @Argument(help: "Name of the skill to show.")
        var name: String

        @Option(name: .long, help: "Path to skills directory (default: ~/.swiftclaw/skills).")
        var directory: String?

        func run() async throws {
            let dir = directory.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            let store = SkillStore(directory: dir)
            do {
                let body = try await store.load(name: name)
                print(body)
            } catch let SkillError.notFound(n) {
                let available = await store.list().map(\.name)
                fputs("Error: skill '\(n)' not found.\n", stderr)
                if !available.isEmpty {
                    fputs("Available: \(available.joined(separator: ", "))\n", stderr)
                }
                throw ExitCode.failure
            }
        }
    }
}
