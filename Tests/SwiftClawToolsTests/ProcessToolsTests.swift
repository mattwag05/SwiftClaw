import Testing
import Foundation
@testable import SwiftClawTools
@testable import SwiftClawCore

@Suite("ProcessTools Tests")
struct ProcessToolsTests {

    @Test("processTools returns 4 tools with expected names")
    func processToolNames() {
        let monitor = ProcessMonitor()
        let tools = SwiftClawToolFactory.processTools(monitor: monitor)
        let names = Set(tools.map { $0.name })
        #expect(tools.count == 4)
        #expect(names.contains("start_process"))
        #expect(names.contains("process_output"))
        #expect(names.contains("stop_process"))
        #expect(names.contains("list_monitored_processes"))
    }

    @Test("start_process and stop_process require confirmation")
    func startAndStopRequireConfirmation() {
        let monitor = ProcessMonitor()
        let tools = SwiftClawToolFactory.processTools(monitor: monitor)
        let start = tools.first(where: { $0.name == "start_process" })
        let stop = tools.first(where: { $0.name == "stop_process" })
        #expect(start?.requiresConfirmation == true)
        #expect(stop?.requiresConfirmation == true)
    }

    @Test("process_output and list_monitored_processes do not require confirmation")
    func outputAndListDoNotRequireConfirmation() {
        let monitor = ProcessMonitor()
        let tools = SwiftClawToolFactory.processTools(monitor: monitor)
        let output = tools.first(where: { $0.name == "process_output" })
        let list = tools.first(where: { $0.name == "list_monitored_processes" })
        #expect(output?.requiresConfirmation == false)
        #expect(list?.requiresConfirmation == false)
    }

    @Test("processTools tool names are unique")
    func processToolNamesAreUnique() {
        let monitor = ProcessMonitor()
        let tools = SwiftClawToolFactory.processTools(monitor: monitor)
        let names = tools.map { $0.name }
        let unique = Set(names)
        #expect(names.count == unique.count)
    }
}
