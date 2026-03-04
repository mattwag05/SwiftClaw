import Foundation
import SwiftClawCore

/// Lists running processes sorted by memory usage.
public struct ProcessListTool: SwiftClawTool {
    public let name = "process_list"
    public let description = "List running processes sorted by memory usage. Optionally limit the number of results."

    public let parameterSchema: JSONSchema = .object(
        properties: [
            "limit": .integer(description: "Maximum number of processes to return (default: 20)")
        ],
        required: []
    )

    public init() {}

    private struct Arguments: Decodable {
        var limit: Int?
    }

    public func execute(arguments: String) async throws -> ToolResult {
        let args = try JSONDecoder().decode(
            Arguments.self, from: Data(arguments.utf8))
        let limit = args.limit ?? 20

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/ps")
            // macOS ps: -m sorts by memory, -a shows all users' processes
            process.arguments = ["-a", "-x", "-m", "-o", "pid,user,%cpu,%mem,command"]

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                continuation.resume(returning: .failure("Failed to run ps: \(error.localizedDescription)"))
                return
            }

            // Drain pipes BEFORE waitUntilExit to prevent deadlock
            // when output exceeds the pipe buffer (~64KB).
            // Use nonisolated(unsafe) to satisfy strict concurrency for
            // GCD closures that are synchronized by DispatchGroup.
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

            guard process.terminationStatus == 0 else {
                let stderr = String(data: stderrData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                continuation.resume(returning: .failure("ps failed (exit \(process.terminationStatus)): \(stderr)"))
                return
            }

            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""

            // Take header + limit lines
            let lines = stdout.components(separatedBy: "\n")
            let header = lines.first ?? ""
            let body = lines.dropFirst().prefix(limit)
            let result = ([header] + body).joined(separator: "\n")

            continuation.resume(returning: .success(result))
        }
    }
}
