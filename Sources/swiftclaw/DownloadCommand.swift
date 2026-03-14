import ArgumentParser
import Foundation
import SwiftClawCore
import SwiftClawMLX

struct DownloadCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download and cache a model for offline use.",
        discussion: """
            Downloads model weights to the local HuggingFace cache without running inference.

            Aliases:
              default     — downloads the default LLM (\(SwiftClawVersion.defaultModelId))
              embeddings  — downloads the default embedding model
            """
    )

    @Argument(help: "HuggingFace model ID (e.g. mlx-community/Qwen3.5-9B-MLX-4bit) or alias: default, embeddings")
    var modelId: String

    @Flag(name: .long, help: "Download as an embedding model (uses MLXEmbedders loader).")
    var embedding: Bool = false

    mutating func run() async throws {
        let config = (try? SwiftClawConfig.load()) ?? .default
        let resolvedId = resolveAlias(modelId, config: config)
        let isEmbedding = embedding || isEmbeddingAlias(modelId)

        print("Downloading \(isEmbedding ? "embedding" : "LLM") model: \(resolvedId)")

        let progress: @Sendable (Double) -> Void = { fraction in
            let pct = Int(fraction * 100)
            if pct % 5 == 0 {
                let filled = pct / 5
                let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: 20 - filled)
                print("  [\(bar)] \(pct)%", terminator: "\r")
                fflush(stdout)
            }
        }

        do {
            let cacheURL: URL
            if isEmbedding {
                cacheURL = try await downloadMLXEmbeddingModel(
                    modelId: resolvedId,
                    progressHandler: progress
                )
            } else {
                cacheURL = try await downloadMLXModel(
                    modelId: resolvedId,
                    progressHandler: progress
                )
            }

            print()  // newline after progress bar
            print("Downloaded to: \(cacheURL.path)")

            if let size = directorySize(cacheURL) {
                let mb = Double(size) / 1_048_576
                print("Cache size: \(String(format: "%.1f", mb)) MB")
            }

        } catch {
            print()  // newline after partial progress bar
            throw ValidationError("Download failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func resolveAlias(_ id: String, config: SwiftClawConfig) -> String {
        switch id.lowercased() {
        case "default":
            return SwiftClawVersion.defaultModelId
        case "embeddings", "embedding":
            return config.embeddingModelId
        default:
            return id
        }
    }

    private func isEmbeddingAlias(_ id: String) -> Bool {
        id.lowercased() == "embeddings" || id.lowercased() == "embedding"
    }

    private func directorySize(_ url: URL) -> Int? {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var total = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += size
            }
        }
        return total
    }
}
