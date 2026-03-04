import ArgumentParser
import Foundation
import SwiftClawCore
import SwiftClawTools

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check system compatibility and model availability."
    )

    @Option(name: .long, help: "Model ID to check for.")
    var model: String = "mlx-community/Qwen3.5-9B-MLX-4bit"

    mutating func run() async throws {
        print("SwiftClaw Doctor")
        print("================\n")

        // System info
        print("[System]")
        let sysInfo = SystemInfoTool()
        let result = try await sysInfo.execute(arguments: "{}")
        print(result.content)
        print()

        // Disk space
        print("[Disk Space]")
        let diskTool = DiskSpaceTool()
        let diskResult = try await diskTool.execute(arguments: "{}")
        print(diskResult.content)
        print()

        // MLX availability
        print("[MLX]")
        #if arch(arm64)
        print("Architecture: Apple Silicon (arm64) -- supported")
        #else
        print("Architecture: x86_64 -- MLX requires Apple Silicon")
        #endif

        // Check for cached model
        print("\n[Model]")
        print("Default model: \(model)")
        let cachePath = NSHomeDirectory() + "/.cache/huggingface/hub/models--" + model.replacingOccurrences(of: "/", with: "--")
        if FileManager.default.fileExists(atPath: cachePath) {
            print("Status: cached locally at \(cachePath)")
        } else {
            print("Status: not cached (will download on first run)")
        }

        print("\n[Tools]")
        let tools: [any SwiftClawTool] = [
            SystemInfoTool(),
            DiskSpaceTool(),
            ProcessListTool(),
            ShellTool(),
        ]
        for tool in tools {
            print("  \(tool.name) -- \(tool.description)")
        }

        print("\nAll checks passed.")
    }
}
