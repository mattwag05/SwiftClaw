import Foundation
import SwiftClawCore

/// Locates and runs the `pippin` CLI binary.
public struct PippinRunner: Sendable {
    private static let searchPaths = [
        "/opt/homebrew/bin/pippin",
        "/usr/local/bin/pippin",
        "\(NSHomeDirectory())/.local/bin/pippin",
    ]

    /// Returns the path to the pippin binary, or nil if not installed.
    public static func binaryPath() -> String? {
        for path in searchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    private let binaryPath: String

    public init?(binaryPath: String? = nil) {
        if let path = binaryPath {
            guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
            self.binaryPath = path
        } else if let path = Self.binaryPath() {
            self.binaryPath = path
        } else {
            return nil
        }
    }

    /// Runs a pippin subcommand. Always appends `--format json`.
    public func run(
        subcommand: String,
        arguments: [String] = [],
        timeout: Int = 30
    ) async -> Result<String, PippinError> {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = [subcommand] + arguments + ["--format", "json"]

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let timeoutItem = DispatchWorkItem { [process] in
                guard process.isRunning else { return }
                process.terminate()
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(2)) {
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                }
            }

            do {
                try process.run()
            } catch {
                timeoutItem.cancel()
                continuation.resume(returning: .failure(.launchFailed(error.localizedDescription)))
                return
            }

            DispatchQueue.global().asyncAfter(
                deadline: .now() + .seconds(timeout),
                execute: timeoutItem
            )

            nonisolated(unsafe) var stdoutData = Data()
            nonisolated(unsafe) var stderrData = Data()
            let group = DispatchGroup()

            group.enter()
            DispatchQueue.global().async {
                stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            group.wait()
            process.waitUntilExit()
            timeoutItem.cancel()

            if process.terminationReason == .uncaughtSignal {
                continuation.resume(returning: .failure(.timeout(timeout)))
                return
            }

            let stdout = String(data: stdoutData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard process.terminationStatus == 0 else {
                let detail = stderr.isEmpty ? "exit code \(process.terminationStatus)" : stderr
                continuation.resume(returning: .failure(.nonZeroExit(detail)))
                return
            }

            continuation.resume(returning: .success(stdout.isEmpty ? "(no output)" : stdout))
        }
    }
}

public enum PippinError: LocalizedError {
    case notInstalled
    case launchFailed(String)
    case timeout(Int)
    case nonZeroExit(String)

    public var errorDescription: String? {
        switch self {
        case .notInstalled:
            "pippin is not installed (brew install mattwag05/tap/pippin)"
        case let .launchFailed(msg):
            "Failed to launch pippin: \(msg)"
        case let .timeout(seconds):
            "pippin timed out after \(seconds)s"
        case let .nonZeroExit(detail):
            "pippin error: \(detail)"
        }
    }
}
