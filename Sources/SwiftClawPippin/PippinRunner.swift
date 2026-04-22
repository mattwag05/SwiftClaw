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

    /// Runs a pippin subcommand and unwraps the v0.20.0 agent envelope.
    ///
    /// Always appends `--format agent`. On success, returns the envelope's `data`
    /// re-serialized as a pretty-printed JSON string. On envelope-level failure
    /// (status=error), returns ``PippinError/pippinError(code:message:)`` so callers
    /// see a typed code instead of having to scrape stderr.
    public func run(
        subcommand: String,
        arguments: [String] = [],
        timeout: Int = 30
    ) async -> Result<String, PippinError> {
        let raw = await runRaw(subcommand: subcommand, arguments: arguments, timeout: timeout)
        switch raw {
        case let .failure(err):
            return .failure(err)
        case let .success(stdout):
            // Surface empty stdout as a typed error instead of letting it fall
            // through to PippinEnvelope.parse and bubble up as a generic JSON
            // decode failure.
            guard !stdout.isEmpty else {
                return .failure(.envelopeMalformed("empty stdout"))
            }
            do {
                let env = try PippinEnvelope.parse(stdout)
                switch env.status {
                case .ok:
                    return .success(env.dataJSON ?? "null")
                case .error:
                    let info = env.error ?? .init(code: "unknown", message: "no error info")
                    return .failure(.pippinError(code: info.code, message: info.message))
                }
            } catch let err as PippinError {
                return .failure(err)
            } catch {
                return .failure(.envelopeMalformed(error.localizedDescription))
            }
        }
    }

    /// Internal: run pippin and return raw stdout. Does NOT parse the envelope —
    /// kept separate so ``run(subcommand:arguments:timeout:)`` can layer parsing on top
    /// while also giving us a hook for future tooling that wants the raw bytes.
    func runRaw(
        subcommand: String,
        arguments: [String] = [],
        timeout: Int = 30
    ) async -> Result<String, PippinError> {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = [subcommand] + arguments + ["--format", "agent"]

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

            continuation.resume(returning: .success(stdout))
        }
    }
}

public enum PippinError: LocalizedError, Equatable {
    case notInstalled
    case launchFailed(String)
    case timeout(Int)
    case nonZeroExit(String)
    /// The agent envelope parsed cleanly but reported `status=error`.
    case pippinError(code: String, message: String)
    /// The output could not be parsed as a v1 agent envelope.
    case envelopeMalformed(String)
    /// Pippin returned an envelope with a schema version SwiftClaw doesn't understand.
    /// Bump ``PippinEnvelope/supportedSchemaVersion`` (and integration tests) to fix.
    case unsupportedSchemaVersion(Int)

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
        case let .pippinError(code, message):
            "pippin error [\(code)]: \(message)"
        case let .envelopeMalformed(detail):
            "pippin returned an output SwiftClaw could not parse as an agent envelope: \(detail)"
        case let .unsupportedSchemaVersion(v):
            "pippin agent envelope schema v\(v) is newer than SwiftClaw supports (v\(PippinEnvelope.supportedSchemaVersion)). Update SwiftClaw."
        }
    }
}
