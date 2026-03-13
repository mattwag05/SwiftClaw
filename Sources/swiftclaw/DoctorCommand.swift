import ArgumentParser
import Foundation
import SwiftClawCore
import SwiftClawPippin
import SwiftClawTools

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check system compatibility and model availability."
    )

    @Option(name: .long, help: "Model ID to check for.")
    var model: String = SwiftClawVersion.defaultModelId

    mutating func run() async throws {
        print("SwiftClaw Doctor")
        print("================\n")

        var passed = true

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
        passed = false
        #endif

        // Check for cached model
        print("\n[Model]")
        print("Default model: \(model)")
        let cachePath = NSHomeDirectory() + "/Library/Caches/models/" + model
        if FileManager.default.fileExists(atPath: cachePath) {
            print("Status: cached locally at \(cachePath)")
        } else {
            print("Status: not cached (will download on first run)")
            passed = false
        }

        // Embedding model check
        print("\n[Embedding Model]")
        let embeddingModelId = "nomic-ai/nomic-embed-text-v1.5-MLX"
        print("Embedding model: \(embeddingModelId)")
        let embeddingCachePath = NSHomeDirectory() + "/Library/Caches/models/" + embeddingModelId
        if FileManager.default.fileExists(atPath: embeddingCachePath) {
            print("Status: cached locally at \(embeddingCachePath)")
        } else {
            print("Status: not cached (will use hash-based fallback on first run)")
            // Note: this is NOT a failure — embedding model is optional (graceful degradation)
        }

        // Memory database check
        print("\n[Memory Database]")
        let memoryDir = NSHomeDirectory() + "/.swiftclaw/memory"
        let memoryDbPath = memoryDir + "/memories.db"
        let dirExists = FileManager.default.fileExists(atPath: memoryDir)
        let dbExists = FileManager.default.fileExists(atPath: memoryDbPath)
        if dbExists {
            print("Status: database exists at \(memoryDbPath)")
        } else if dirExists {
            print("Status: directory exists, database will be created on first run")
        } else {
            print("Status: will be created at \(memoryDbPath) on first run")
        }

        print("\n[Tools]")
        let config = (try? SwiftClawConfig.load()) ?? .default
        let tools: [any SwiftClawTool] =
            SwiftClawToolFactory.allTools(config: config) + PippinToolFactory.allTools()
        for tool in tools {
            print("  \(tool.name) -- \(tool.description)")
        }
        print("  (memory_write, memory_read, memory_search, memory_delete — available when --memory flag is used)")

        print()
        if passed {
            print("All checks passed.")
        } else {
            print("Some checks failed (see above).")
        }
    }
}
