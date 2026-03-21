import Foundation

public actor ProcessMonitor {

    // MARK: - Private Types

    private struct RingBuffer<Element> {
        private let capacity: Int
        private var buffer: [Element] = []
        private var writeIndex: Int = 0

        init(capacity: Int) { self.capacity = capacity }

        mutating func append(_ element: Element) {
            if buffer.count < capacity {
                buffer.append(element)
            } else {
                buffer[writeIndex % capacity] = element
            }
            writeIndex += 1
        }

        func tail(_ n: Int) -> [Element] {
            let count = buffer.count
            guard count > 0 else { return [] }
            let take = min(n, count)
            if writeIndex <= capacity {
                return Array(buffer.suffix(take))
            }
            // Buffer is full and has wrapped
            var ordered: [Element] = []
            ordered.reserveCapacity(count)
            for i in 0..<count {
                ordered.append(buffer[(writeIndex + i) % capacity])
            }
            return Array(ordered.suffix(take))
        }
    }

    /// `Process` is NOT stored here — keeping it inside DispatchQueue closures
    /// avoids all Sendable and actor-isolation issues with the non-Sendable type.
    private struct ManagedProcess {
        var info: MonitoredProcess
        var outputBuffer: RingBuffer<String>
        let pid: Int32  // Int32 is Sendable — safe across await and actor boundaries
    }

    // MARK: - State

    private var processes: [String: ManagedProcess] = [:]

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Launch a process and optionally wait for a ready marker on stdout.
    ///
    /// All `Process` interaction lives inside a `DispatchQueue.global().async` block
    /// (the ShellTool pattern), so the non-Sendable `Process` object never crosses
    /// an actor isolation boundary or an `await` suspension point.
    ///
    /// - Parameters:
    ///   - command: Executable path or name (resolved via `/usr/bin/env` if not absolute)
    ///   - args: Arguments to pass to the executable
    ///   - readyMarker: Text to watch for on stdout; if nil, returns immediately after launch
    ///   - timeout: Seconds to wait for ready marker (ignored if readyMarker is nil)
    /// - Returns: Process ID string (UUID)
    @discardableResult
    public func launch(
        command: String,
        args: [String] = [],
        readyMarker: String? = nil,
        timeout: TimeInterval = 30
    ) async throws -> String {
        let id = UUID().uuidString

        return try await withCheckedThrowingContinuation { continuation in
            // ── All Process interaction is inside this DispatchQueue block ────────────
            // Process never escapes to an await boundary or crosses actor isolation.
            DispatchQueue.global().async {
                let process = Process()

                // Resolve the executable: absolute paths are used directly;
                // bare names go through /usr/bin/env so $PATH is honoured.
                if command.hasPrefix("/") {
                    process.executableURL = URL(fileURLWithPath: command)
                    process.arguments = args
                } else {
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = [command] + args
                }

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: SwiftClawError.processMonitoringFailed(
                        "Failed to launch '\(command)': \(error.localizedDescription)"
                    ))
                    return
                }

                let pid = process.processIdentifier  // Int32 — Sendable

                // Register the process on the actor using only Sendable values.
                Task {
                    await self.register(
                        id: id,
                        command: command,
                        args: args,
                        pid: pid,
                        hasReadyMarker: readyMarker != nil
                    )
                }

                // ── No ready marker: resume immediately ──────────────────────────────
                guard let marker = readyMarker else {
                    // Drain stdout and stderr in the background so the ring buffer fills.
                    DispatchQueue.global().async {
                        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                        if let text = String(data: data, encoding: .utf8) {
                            for line in text.components(separatedBy: "\n") where !line.isEmpty {
                                Task { await self.appendOutput(id: id, line: line) }
                            }
                        }
                    }
                    DispatchQueue.global().async {
                        let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        if let text = String(data: data, encoding: .utf8) {
                            for line in text.components(separatedBy: "\n") where !line.isEmpty {
                                Task { await self.appendOutput(id: id, line: "[stderr] \(line)") }
                            }
                        }
                        process.waitUntilExit()
                        let exitCode = process.terminationStatus
                        Task { await self.updateState(id: id, state: .stopped(exitCode)) }
                    }
                    continuation.resume(returning: id)
                    return
                }

                // ── Ready-marker watch loop ───────────────────────────────────────────
                // nonisolated(unsafe) boolean flag — only the first event (marker, timeout,
                // or premature exit) resumes the continuation exactly once.
                nonisolated(unsafe) var resumed = false

                // Timeout work item — fires if the marker isn't seen in time.
                let timeoutItem = DispatchWorkItem {
                    guard !resumed else { return }
                    resumed = true
                    Task { await self.updateState(id: id, state: .failed("Timeout waiting for '\(marker)'")) }
                    continuation.resume(throwing: SwiftClawError.processMonitoringFailed(
                        "Timeout waiting for ready marker '\(marker)' from '\(command)'"
                    ))
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

                // Poll stdout line-by-line using availableData.
                // This keeps Process inside the DispatchQueue block (no async/await).
                let stdoutHandle = stdoutPipe.fileHandleForReading
                nonisolated(unsafe) var lineBuffer = ""

                outerLoop: while process.isRunning || stdoutHandle.availableData.count > 0 {
                    let data = stdoutHandle.availableData
                    if data.isEmpty {
                        if !process.isRunning { break }
                        Thread.sleep(forTimeInterval: 0.05)
                        continue
                    }
                    lineBuffer += String(data: data, encoding: .utf8) ?? ""
                    var lines = lineBuffer.components(separatedBy: "\n")
                    lineBuffer = lines.removeLast()  // keep incomplete trailing fragment

                    for line in lines {
                        Task { await self.appendOutput(id: id, line: line) }
                        if !resumed && line.contains(marker) {
                            resumed = true
                            timeoutItem.cancel()
                            Task { await self.updateState(id: id, state: .ready) }
                            continuation.resume(returning: id)
                        }
                    }

                    if resumed {
                        // Drain remaining stdout in background so the ring buffer keeps filling.
                        DispatchQueue.global().async {
                            let tail = stdoutHandle.readDataToEndOfFile()
                            if let text = String(data: tail, encoding: .utf8) {
                                for l in text.components(separatedBy: "\n") where !l.isEmpty {
                                    Task { await self.appendOutput(id: id, line: l) }
                                }
                            }
                        }
                        break outerLoop
                    }
                }

                // Drain stderr and reflect the final exit code.
                DispatchQueue.global().async {
                    let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    if let text = String(data: data, encoding: .utf8) {
                        for line in text.components(separatedBy: "\n") where !line.isEmpty {
                            Task { await self.appendOutput(id: id, line: "[stderr] \(line)") }
                        }
                    }
                    process.waitUntilExit()
                    let exitCode = process.terminationStatus
                    Task { await self.updateState(id: id, state: .stopped(exitCode)) }
                }

                // Process exited without the ready marker — resume with failure.
                if !resumed {
                    timeoutItem.cancel()
                    resumed = true
                    let exitCode = process.terminationStatus
                    Task { await self.updateState(id: id, state: .stopped(exitCode)) }
                    continuation.resume(throwing: SwiftClawError.processMonitoringFailed(
                        "Process '\(command)' exited with code \(exitCode) before ready marker '\(marker)' was seen"
                    ))
                }
            }
        }
    }

    /// Stop a monitored process (SIGTERM → 2s wait → SIGKILL).
    ///
    /// Uses the stored `pid: Int32` (which is `Sendable`) rather than a `Process`
    /// reference, so `kill()` is safe to call across the `await Task.sleep` boundary.
    public func stop(id: String) async throws {
        guard let managed = processes[id] else {
            throw SwiftClawError.processMonitoringFailed("Process \(id) not found")
        }
        let pid = managed.pid  // Int32 — Sendable, safe across await

        // Update state and remove from registry before yielding to the executor.
        processes[id]?.info.state = .stopped(-1)
        processes.removeValue(forKey: id)

        // Send SIGTERM, wait up to 2s, then SIGKILL.
        // kill() with an already-dead pid is a no-op (ESRCH), so the SIGKILL is safe.
        kill(pid, SIGTERM)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        kill(pid, SIGKILL)
    }

    /// List all monitored processes and their current states.
    public func list() -> [MonitoredProcess] {
        processes.values.map { $0.info }
    }

    /// Read recent stdout/stderr lines from a process's ring buffer.
    public func output(id: String, tail: Int = 50) -> [String]? {
        processes[id]?.outputBuffer.tail(tail)
    }

    /// Stop all monitored processes. Called on session end.
    public func shutdown() async {
        let ids = Array(processes.keys)
        for id in ids {
            try? await stop(id: id)
        }
    }

    // MARK: - Actor-isolated Helpers
    // These are called via `Task { await self.xxx(...) }` from DispatchQueue blocks.
    // Only Sendable types (String, Int32, Date, ProcessState) cross the boundary.

    private func register(
        id: String,
        command: String,
        args: [String],
        pid: Int32,
        hasReadyMarker: Bool
    ) {
        let info = MonitoredProcess(
            id: id,
            command: command,
            args: args,
            state: hasReadyMarker ? .launching : .ready,
            pid: pid,
            startTime: Date()
        )
        processes[id] = ManagedProcess(
            info: info,
            outputBuffer: RingBuffer(capacity: 500),
            pid: pid
        )
    }

    private func appendOutput(id: String, line: String) {
        processes[id]?.outputBuffer.append(line)
    }

    private func updateState(id: String, state: ProcessState) {
        processes[id]?.info.state = state
    }
}
