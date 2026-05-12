import Foundation
import SwiftClawCore

/// Runs a shell command inside the session workspace.
///
/// Safety layers (in order):
/// 1. Denylist — unconditionally blocks dangerous patterns (sudo, rm -rf /, curl|bash, etc.)
/// 2. Allowlist — auto-approves commands matching a persisted prefix list
/// 3. Approval prompt — calls the delegate for commands not on either list
///
/// Execution: `/bin/bash -lc <cmd>`, cwd = workspace, 60s SIGKILL timeout,
/// 16 KB combined stdout+stderr cap.
public struct RunBashTool: SwiftClawTool {
    public let name = "run_bash"
    public let requiresConfirmation = false   // handled per-command via allowlist/delegate
    public let description =
        "Run a shell command in the workspace directory. Subject to denylist and allowlist checks."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "command": .string(description: "Shell command to run"),
        ],
        required: ["command"]
    )

    private let workspaceURL: URL
    private let allowlist: BashAllowlist
    private let approvalDelegate: (any BashApprovalDelegate)?
    private static let maxOutputBytes = 16_384
    private static let timeoutSeconds: Double = 60

    public init(
        workspaceURL: URL,
        allowlist: BashAllowlist,
        approvalDelegate: (any BashApprovalDelegate)? = nil
    ) {
        self.workspaceURL = workspaceURL
        self.allowlist = allowlist
        self.approvalDelegate = approvalDelegate
    }

    private struct Arguments: Decodable {
        var command: String
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(Arguments.self, from: Data(arguments.utf8))
        let command = args.command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return .failure("Empty command") }

        let decision = await allowlist.decision(for: command)
        switch decision {
        case .blocked:
            return .failure("Command blocked by denylist: \(command)")
        case .allowed:
            break
        case .requiresPrompt:
            guard await requestApproval(command: command) else {
                return .failure("Command denied by user")
            }
        }

        return await runProcess(command: command)
    }

    private func requestApproval(command: String) async -> Bool {
        guard let delegate = approvalDelegate else { return false }
        let requestId = UUID().uuidString
        let result = await delegate.approveBash(command: command, requestId: requestId)
        switch result {
        case .allowOnce:
            return true
        case .allowSession, .addToAllowlist:
            try? await allowlist.add(prefix: command)
            return true
        case .deny:
            return false
        }
    }

    private func runProcess(command: String) async -> ToolResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-lc", command]
            process.currentDirectoryURL = workspaceURL

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

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

            do {
                try process.run()
            } catch {
                continuation.resume(returning: .failure("Failed to start: \(error.localizedDescription)"))
                return
            }

            // Capture pid after run() — processIdentifier is 0 before the process starts.
            let pid = process.processIdentifier
            let timeoutTask = Task {
                try await Task.sleep(for: .seconds(Self.timeoutSeconds))
                if pid != 0 { kill(pid, SIGKILL) }
            }

            group.notify(queue: .global()) {
                timeoutTask.cancel()
                process.waitUntilExit()

                let combined = (stdoutData + stderrData).prefix(Self.maxOutputBytes)
                let output = String(data: combined, encoding: .utf8) ?? "(non-UTF-8 output)"
                let exitCode = process.terminationStatus

                let truncated = (stdoutData.count + stderrData.count) > Self.maxOutputBytes
                    ? "\n[Output truncated at 16KB]" : ""
                let result = output + truncated

                if exitCode == 0 {
                    continuation.resume(returning: .success(result.isEmpty ? "(no output)" : result))
                } else {
                    continuation.resume(returning: .failure("Exit \(exitCode): \(result)"))
                }
            }
        }
    }
}
