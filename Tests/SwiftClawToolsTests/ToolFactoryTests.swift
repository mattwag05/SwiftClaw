import Foundation
import Testing
@testable import SwiftClawTools
@testable import SwiftClawCore

@Suite("ToolFactory Tests")
struct ToolFactoryTests {
    @Test("allTools returns 12 built-in tools")
    func allToolsCount() {
        let tools = SwiftClawToolFactory.allTools()
        #expect(tools.count == 12)
    }

    @Test("allTools tool names are unique")
    func allToolsUniqueNames() {
        let tools = SwiftClawToolFactory.allTools()
        let names = tools.map(\.name)
        let unique = Set(names)
        #expect(names.count == unique.count)
    }

    @Test("allTools includes all expected names")
    func allToolsExpectedNames() {
        let tools = SwiftClawToolFactory.allTools()
        let names = Set(tools.map(\.name))
        let expected: Set<String> = [
            "system_info", "disk_space", "process_list", "shell",
            "read_file", "write_file", "edit_file", "list_directory", "find_files",
            "env_vars", "date_time", "clipboard",
        ]
        #expect(names == expected)
    }

    @Test("allTools with custom config uses custom sandbox paths")
    func allToolsCustomConfig() {
        let config = SwiftClawConfig(
            fileSandbox: FileSandboxConfig(allowedPaths: ["/tmp", "~"])
        )
        let tools = SwiftClawToolFactory.allTools(config: config)
        #expect(tools.count == 12)
    }
}
