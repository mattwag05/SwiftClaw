import Foundation
import SwiftClawCore

/// Reports system information: hostname, OS, CPU, memory.
public struct SystemInfoTool: SwiftClawTool {
    public let name = "system_info"
    public let description = "Get system information including hostname, OS version, CPU count, and memory."

    public let parameterSchema: JSONSchema = .object(properties: [:], required: [])

    public init() {}

    public func execute(arguments: String) async throws -> ToolResult {
        let info = ProcessInfo.processInfo
        var utsName = utsname()
        uname(&utsName)

        let machine = withUnsafePointer(to: &utsName.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        let sysname = withUnsafePointer(to: &utsName.sysname) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        let release = withUnsafePointer(to: &utsName.release) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }

        let memoryGB = Double(info.physicalMemory) / 1_073_741_824
        let lines = [
            "Hostname: \(info.hostName)",
            "OS: \(sysname) \(release)",
            "Architecture: \(machine)",
            "CPU cores: \(info.processorCount) (\(info.activeProcessorCount) active)",
            "Memory: \(String(format: "%.1f", memoryGB)) GB",
            "Uptime: \(formatUptime(info.systemUptime))",
        ]
        return .success(lines.joined(separator: "\n"))
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
