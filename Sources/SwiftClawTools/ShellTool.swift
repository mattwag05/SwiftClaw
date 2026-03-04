import Foundation
import SwiftClawCore

/// Executes sandboxed shell commands with an allowlist and timeout.
public struct ShellTool: SwiftClawTool {
    public let name = "shell"
    public let description =
        "Run a sandboxed shell command. Only allowlisted commands are permitted (ls, cat, grep, df, ps, uptime, etc). No pipes, redirects, or chaining."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "command": .string(description: "The command to run (e.g. 'ls -la /tmp')"),
            "timeout": .integer(description: "Timeout in seconds (default: 30, max: 120)"),
        ],
        required: ["command"]
    )

    private let sandbox: ShellSandbox

    public init(sandbox: ShellSandbox = ShellSandbox()) {
        self.sandbox = sandbox
    }

    private struct Arguments: Decodable {
        var command: String
        var timeout: Int?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(
            Arguments.self, from: Data(arguments.utf8))
        let timeout = min(args.timeout ?? 30, 120)

        let validated: (executable: String, arguments: [String])
        do {
            validated = try sandbox.validate(command: args.command)
        } catch {
            return .failure(error.localizedDescription)
        }

        return await runProcess(
            executable: validated.executable,
            arguments: validated.arguments,
            timeout: timeout
        )
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        timeout: Int
    ) async -> ToolResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Timeout handling
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
                continuation.resume(returning: .failure("Failed to execute: \(error.localizedDescription)"))
                return
            }

            DispatchQueue.global().asyncAfter(
                deadline: .now() + .seconds(timeout),
                execute: timeoutItem
            )

            process.waitUntilExit()
            timeoutItem.cancel()

            if process.terminationReason == .uncaughtSignal {
                continuation.resume(returning: .failure("Command timed out after \(timeout)s"))
                return
            }

            let stdout = String(
                data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let stderr = String(
                data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard process.terminationStatus == 0 else {
                let detail = stderr.isEmpty ? "exit code \(process.terminationStatus)" : stderr
                continuation.resume(returning: .failure(detail))
                return
            }

            let output = stderr.isEmpty ? stdout : "\(stdout)\n\nstderr:\n\(stderr)"
            continuation.resume(returning: .success(output.isEmpty ? "(no output)" : output))
        }
    }
}
