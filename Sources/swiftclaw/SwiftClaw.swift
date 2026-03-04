import ArgumentParser
import SwiftClawCore

@main
struct SwiftClawCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftclaw",
        abstract: SwiftClawVersion.tagline,
        version: "swiftclaw \(SwiftClawVersion.version)",
        subcommands: [RunCommand.self, ToolsCommand.self, DoctorCommand.self]
    )
}
