import ArgumentParser
import Foundation
import SwiftClawCore
import SwiftClawTools

struct ToolsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tools",
        abstract: "List available agent tools."
    )

    @Flag(name: .long, help: "Output tool schemas as JSON.")
    var json = false

    mutating func run() async throws {
        let tools: [any SwiftClawTool] = [
            SystemInfoTool(),
            DiskSpaceTool(),
            ProcessListTool(),
            ShellTool(),
        ]

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let definitions = tools.map(\.definition)
            let data = try encoder.encode(definitions)
            print(String(data: data, encoding: .utf8) ?? "")
        } else {
            print("Available Tools (\(tools.count))")
            print("=================\n")
            for tool in tools {
                print("  \(tool.name)")
                print("    \(tool.description)\n")
            }
        }
    }
}
