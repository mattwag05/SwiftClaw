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
        var pid: Int32  // Int32 is Sendable — safe across await and actor boundaries
    }

    // MARK: - State

    private var processes: [String: ManagedProcess] = [:]

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Launch a process and optionally wait for a ready marker on stdout.
    ///
    /// The entry is pre-registered with `.launching` state BEFORE the continuation
    /// is created, so callers can safely call `output(id:)` or `stop(id:)` as soon
    /// as `launch()` returns without racing against the `register()` Task.
    ///
    /// All `Process` interaction lives inside a `DispatchQueue.global().async` block
    /// (the ShellTool pattern), so the non-Sendable `Process` object never crosses
    /// an actor isolation boundary or an `await` suspension point.
    ///
    /// `FileHandle.readabilityHandler` replaces the polling loop, eliminating the
    /// TOCTOU double-read of `availableData`.
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

        // Pre-register with .launching state so callers always find the entry,
        // even if they query immediately after launch() returns.
        processes[id] = ManagedProcess(
            info: MonitoredProcess(
                id: id,
                command: command,
                args: args,
                state: .launching,
                pid: nil,
                startTime: Date()
            ),
            outputBuffer: RingBuffer(capacity: 500),
            pid: 0  // placeholder; updated via updatePid() once process actually starts
        )

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
                    Task { await self.removeProcess(id: id) }
                    continuation.resume(throwing: SwiftClawError.processMonitoringFailed(
                        "Failed to launch '\(command)': \(error.localizedDescription)"
                    ))
                    return
                }

                let pid = process.processIdentifier  // Int32 — Sendable
                Task { await self.updatePid(id: id, pid: pid) }

                let stdoutHandle = stdoutPipe.fileHandleForReading

                // ── No ready marker: set up readabilityHandler and resume immediately ──
                guard let marker = readyMarker else {
                    stdoutHandle.readabilityHandler = { fh in
                        let data = fh.availableData
                        if data.isEmpty {
                            // EOF — process has closed its stdout end
                            fh.readabilityHandler = nil
                            return
                        }
                        if let text = String(data: data, encoding: .utf8) {
                            for line in text.components(separatedBy: "\n") where !line.isEmpty {
                                Task { await self.appendOutput(id: id, line: line) }
                            }
                        }
                    }
                    // Drain stderr and reflect final exit code via terminationHandler.
                    process.terminationHandler = { p in
                        stdoutHandle.readabilityHandler = nil
                        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        if let text = String(data: stderrData, encoding: .utf8) {
                            for line in text.components(separatedBy: "\n") where !line.isEmpty {
                                Task { await self.appendOutput(id: id, line: "[stderr] \(line)") }
                            }
                        }
                        let exitCode = p.terminationStatus
                        Task { await self.updateState(id: id, state: .stopped(exitCode)) }
                    }
                    Task { await self.updateState(id: id, state: .ready) }
                    continuation.resume(returning: id)
                    return
                }

                // ── Ready-marker watch ────────────────────────────────────────────────
                // resumeQueue serializes the resume-once check across the two
                // uncoordinated GCD queues (readabilityHandler's private queue and the
                // timeout DispatchWorkItem on DispatchQueue.global()).
                // nonisolated(unsafe) is still required — `resumed` is a non-Sendable
                // var captured across contexts — but is now protected by the mutex.
                let resumeQueue = DispatchQueue(label: "com.swiftclaw.process-\(id)-resume")
                nonisolated(unsafe) var resumed = false
                nonisolated(unsafe) var lineBuffer = ""

                // Timeout work item — fires if the marker isn't seen in time.
                let timeoutItem = DispatchWorkItem {
                    var shouldResume = false
                    resumeQueue.sync {
                        if !resumed {
                            resumed = true
                            shouldResume = true
                        }
                    }
                    guard shouldResume else { return }
                    stdoutHandle.readabilityHandler = nil
                    Task { await self.updateState(id: id, state: .failed("Timeout waiting for '\(marker)'")) }
                    continuation.resume(throwing: SwiftClawError.processMonitoringFailed(
                        "Timeout waiting for ready marker '\(marker)' from '\(command)'"
                    ))
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

                // readabilityHandler is called on a private GCD queue each time data
                // is available. EOF is signaled by an empty Data read.
                stdoutHandle.readabilityHandler = { fh in
                    let data = fh.availableData
                    if data.isEmpty {
                        // EOF — process exited before the ready marker was seen.
                        fh.readabilityHandler = nil
                        var shouldResume = false
                        resumeQueue.sync {
                            if !resumed {
                                resumed = true
                                shouldResume = true
                            }
                        }
                        guard shouldResume else { return }
                        timeoutItem.cancel()
                        // terminationStatus is safe to read here: EOF on the pipe
                        // means the write end is closed, which only happens after exit.
                        let exitCode = process.terminationStatus
                        Task { await self.updateState(id: id, state: .stopped(exitCode)) }
                        continuation.resume(throwing: SwiftClawError.processMonitoringFailed(
                            "Process '\(command)' exited with code \(exitCode) before ready marker '\(marker)' was seen"
                        ))
                        return
                    }

                    let chunk = String(data: data, encoding: .utf8) ?? ""
                    lineBuffer += chunk
                    var lines = lineBuffer.components(separatedBy: "\n")
                    lineBuffer = lines.removeLast()  // keep incomplete trailing fragment

                    for line in lines where !line.isEmpty {
                        Task { await self.appendOutput(id: id, line: line) }
                        var shouldResume = false
                        resumeQueue.sync {
                            if !resumed, line.contains(marker) {
                                resumed = true
                                shouldResume = true
                            }
                        }
                        if shouldResume {
                            timeoutItem.cancel()
                            fh.readabilityHandler = nil
                            Task { await self.updateState(id: id, state: .ready) }
                            continuation.resume(returning: id)
                            // Don't break — remaining lines in this batch still get buffered
                            // via the appendOutput Tasks that already fired above the marker.
                        }
                    }
                }

                // terminationHandler: drain stderr and update final state.
                // If the process exits after the marker was seen, this just records the
                // exit code. If it exits before (and readabilityHandler fires EOF first),
                // this is a no-op because the handler already updated state.
                process.terminationHandler = { p in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                        stdoutHandle.readabilityHandler = nil
                        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        if let text = String(data: stderrData, encoding: .utf8) {
                            for line in text.components(separatedBy: "\n") where !line.isEmpty {
                                Task { await self.appendOutput(id: id, line: "[stderr] \(line)") }
                            }
                        }
                        let exitCode = p.terminationStatus
                        Task { await self.updateState(id: id, state: .stopped(exitCode)) }
                    }
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

        // Guard against placeholder pid — process hasn't started yet.
        // kill(0, sig) sends to the entire process group; remove and return safely.
        guard pid != 0 else {
            processes.removeValue(forKey: id)
            return
        }

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
    // These are called via `Task { await self.xxx(...) }` from DispatchQueue blocks
    // and readabilityHandler closures. Only Sendable types cross the boundary.

    private func updatePid(id: String, pid: Int32) {
        guard var managed = processes[id] else { return }
        managed.info = MonitoredProcess(
            id: id,
            command: managed.info.command,
            args: managed.info.args,
            state: managed.info.state,
            pid: pid,
            startTime: managed.info.startTime
        )
        managed.pid = pid
        processes[id] = managed
    }

    private func removeProcess(id: String) {
        processes.removeValue(forKey: id)
    }

    private func appendOutput(id: String, line: String) {
        processes[id]?.outputBuffer.append(line)
    }

    private func updateState(id: String, state: ProcessState) {
        processes[id]?.info.state = state
    }
}
