import Testing
import Foundation
@testable import SwiftClawCore

@Suite("ProcessMonitor Tests")
struct ProcessMonitorTests {

    @Test("Launch with no ready marker transitions to ready")
    func launchNoMarkerIsReady() async throws {
        let monitor = ProcessMonitor()
        let id = try await monitor.launch(command: "/bin/sleep", args: ["60"])
        let procs = await monitor.list()
        let state = procs.first(where: { $0.id == id })?.state
        #expect(state == .ready)
        try await monitor.stop(id: id)
    }

    @Test("Ready marker detected on stdout")
    func readyMarkerDetected() async throws {
        let monitor = ProcessMonitor()
        let id = try await monitor.launch(
            command: "/bin/sh",
            args: ["-c", "echo __READY__; sleep 60"],
            readyMarker: "__READY__",
            timeout: 10
        )
        let procs = await monitor.list()
        let state = procs.first(where: { $0.id == id })?.state
        #expect(state == .ready)
        try await monitor.stop(id: id)
    }

    @Test("Ring buffer captures output lines")
    func outputRingBufferReturnLines() async throws {
        let monitor = ProcessMonitor()
        let id = try await monitor.launch(
            command: "/bin/sh",
            args: ["-c", "for i in 1 2 3 4 5; do echo line$i; done; sleep 60"],
            readyMarker: "line5",
            timeout: 10
        )
        // Give a moment for output to be flushed into the ring buffer
        try await Task.sleep(nanoseconds: 300_000_000)
        let lines = await monitor.output(id: id)
        #expect(lines != nil)
        #expect(lines!.count >= 5)
        try await monitor.stop(id: id)
    }

    @Test("List returns all launched processes")
    func listReturnsAllProcesses() async throws {
        let monitor = ProcessMonitor()
        let id1 = try await monitor.launch(command: "/bin/sleep", args: ["60"])
        let id2 = try await monitor.launch(command: "/bin/sleep", args: ["60"])
        let procs = await monitor.list()
        #expect(procs.contains(where: { $0.id == id1 }))
        #expect(procs.contains(where: { $0.id == id2 }))
        await monitor.shutdown()
    }

    @Test("Shutdown stops all processes and clears list")
    func shutdownStopsAll() async throws {
        let monitor = ProcessMonitor()
        _ = try await monitor.launch(command: "/bin/sleep", args: ["60"])
        _ = try await monitor.launch(command: "/bin/sleep", args: ["60"])
        await monitor.shutdown()
        let procs = await monitor.list()
        #expect(procs.isEmpty)
    }

    @Test("Output returns nil for unknown process ID")
    func outputNilForUnknownID() async {
        let monitor = ProcessMonitor()
        let lines = await monitor.output(id: "nonexistent-id")
        #expect(lines == nil)
    }

    @Test("Stop throws for unknown process ID")
    func stopThrowsForUnknownID() async {
        let monitor = ProcessMonitor()
        await #expect(throws: SwiftClawError.self) {
            try await monitor.stop(id: "does-not-exist")
        }
    }
}
