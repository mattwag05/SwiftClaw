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

    private struct ManagedProcess {
        var info: MonitoredProcess
        var outputBuffer: RingBuffer<String>
        var process: Process
        var watchTask: Task<Void, Never>?
    }

    // MARK: - State

    private var processes: [String: ManagedProcess] = [:]

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Launch a process and optionally wait for a ready marker on stdout.
    /// - Parameters:
    ///   - command: Full path or name of the executable (e.g. "/usr/bin/python3")
    ///   - args: Arguments to pass to the executable
    ///   - readyMarker: Text to watch for in stdout; if nil, transitions to .ready immediately on launch
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

        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let info = MonitoredProcess(
            id: id,
            command: command,
            args: args,
            state: .launching,
            pid: nil,
            startTime: Date()
        )

        let managed = ManagedProcess(
            info: info,
            outputBuffer: RingBuffer<String>(capacity: 500),
            process: process,
            watchTask: nil
        )
        processes[id] = managed

        do {
            try process.run()
        } catch {
            processes[id]?.info.state = .failed(error.localizedDescription)
            throw SwiftClawError.processMonitoringFailed("Failed to launch '\(command)': \(error.localizedDescription)")
        }

        // Update pid now that process is running
        processes[id]?.info = MonitoredProcess(
            id: id,
            command: command,
            args: args,
            state: .launching,
            pid: process.processIdentifier,
            startTime: info.startTime
        )

        if let marker = readyMarker {
            // Set up continuation-based ready-marker wait.
            // The watch task reads stdout lines; when it sees the marker it resumes the continuation.
            // A parallel timeout task resumes with failure after `timeout` seconds.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // Nonisolated(unsafe) wrapper so the continuation can be shared between two tasks.
                // Both tasks use a simple "first one wins" flag via an actor-isolated helper, but
                // since we can't call actor methods from a nonisolated context with checked continuation,
                // we use an atomic flag via a class reference.
                let once = OnceFlag()

                // Timeout task
                let timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    if once.claim() {
                        continuation.resume(throwing: SwiftClawError.processMonitoringFailed(
                            "Timed out waiting for ready marker '\(marker)' from '\(command)'"
                        ))
                    }
                }

                // Watch task: reads stdout lines, appends to ring buffer, watches for marker
                let watchTask = Task { [weak self] in
                    defer { timeoutTask.cancel() }
                    let fileHandle = stdoutPipe.fileHandleForReading
                    do {
                        for try await line in fileHandle.bytes.lines {
                            await self?.appendOutput(id: id, line: line)
                            if line.contains(marker) {
                                if once.claim() {
                                    continuation.resume()
                                }
                                // Keep reading output even after marker fires
                            }
                            if Task.isCancelled { break }
                        }
                    } catch {
                        // I/O error reading stdout — treat as process exit
                    }
                    // Stdout closed (process exited) — if marker never seen, resume with error
                    if once.claim() {
                        continuation.resume(throwing: SwiftClawError.processMonitoringFailed(
                            "Process '\(command)' exited before ready marker '\(marker)' was seen"
                        ))
                    }
                }

                // Store the watch task so stop() can cancel it
                processes[id]?.watchTask = watchTask
            }

            // Mark ready (or it already failed via throw above)
            processes[id]?.info.state = .ready

        } else {
            // No ready marker — transition immediately
            processes[id]?.info.state = .ready

            // Still need a watch task to capture output
            let watchTask = Task { [weak self] in
                let fileHandle = stdoutPipe.fileHandleForReading
                do {
                    for try await line in fileHandle.bytes.lines {
                        await self?.appendOutput(id: id, line: line)
                        if Task.isCancelled { break }
                    }
                } catch {
                    // I/O error — process likely exited
                }
            }
            processes[id]?.watchTask = watchTask
        }

        // Also drain stderr into the ring buffer
        let stderrTask = Task { [weak self] in
            let fileHandle = stderrPipe.fileHandleForReading
            do {
                for try await line in fileHandle.bytes.lines {
                    await self?.appendOutput(id: id, line: "[stderr] \(line)")
                    if Task.isCancelled { break }
                }
            } catch {
                // I/O error — process likely exited
            }
        }
        // We don't track stderrTask for cancellation — it finishes naturally when the process exits.
        _ = stderrTask

        return id
    }

    /// Stop a monitored process (SIGTERM → 2s wait → SIGKILL).
    public func stop(id: String) async throws {
        guard let managed = processes[id] else {
            throw SwiftClawError.processMonitoringFailed("Process \(id) not found")
        }
        let proc = managed.process
        managed.watchTask?.cancel()
        proc.terminate()
        // Wait up to 2s for graceful exit, then SIGKILL
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if proc.isRunning {
            kill(proc.processIdentifier, SIGKILL)
        }
        processes[id]?.info.state = .stopped(proc.terminationStatus)
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
        for id in processes.keys {
            try? await stop(id: id)
        }
    }

    // MARK: - Actor-isolated Helpers

    private func appendOutput(id: String, line: String) {
        processes[id]?.outputBuffer.append(line)
    }

    private func transitionState(id: String, state: ProcessState) {
        processes[id]?.info.state = state
    }
}

// MARK: - OnceFlag

/// Thread-safe "first caller wins" flag backed by a lock.
/// Used to ensure only one of (watch task, timeout task) resumes the continuation.
private final class OnceFlag: @unchecked Sendable {
    private var claimed = false
    private let lock = NSLock()

    /// Returns true if this is the first call to `claim()`.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
