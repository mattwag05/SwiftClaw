import Foundation
import SwiftClawCore

/// Discovers MLX models cached on the local filesystem.
public struct MLXModelScanner: Sendable {
    let cacheBase: URL?

    public init(cacheBase: URL? = nil) {
        self.cacheBase = cacheBase
    }

    /// Scans `~/Library/Caches/models/` for downloaded model directories.
    /// Each subdirectory containing a `config.json` is treated as a valid model.
    public func listCachedModels() async -> [DiscoveredModel] {
        let injectedBase = cacheBase
        return await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let cacheBase: URL
            if let base = injectedBase {
                cacheBase = base
            } else {
                guard let computed = fm.urls(for: .cachesDirectory, in: .userDomainMask)
                    .first?.appendingPathComponent("models") else { return [] }
                cacheBase = computed
            }

            guard let orgDirs = try? fm.contentsOfDirectory(
                at: cacheBase, includingPropertiesForKeys: [.isDirectoryKey]
            ) else { return [] }

            var results: [DiscoveredModel] = []
            for orgDir in orgDirs {
                guard let isDir = try? orgDir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                      isDir else { continue }
                let org = orgDir.lastPathComponent

                guard let modelDirs = try? fm.contentsOfDirectory(
                    at: orgDir, includingPropertiesForKeys: [.isDirectoryKey]
                ) else { continue }

                for modelDir in modelDirs {
                    guard let isModelDir = try? modelDir.resourceValues(
                        forKeys: [.isDirectoryKey]
                    ).isDirectory, isModelDir else { continue }

                    let configURL = modelDir.appendingPathComponent("config.json")
                    guard let data = try? Data(contentsOf: configURL) else { continue }

                    let modelName = modelDir.lastPathComponent
                    let fullId = "\(org)/\(modelName)"
                    let info = Self.parseConfig(data: data)
                    let dirSize = Self.directorySize(at: modelDir)

                    results.append(DiscoveredModel(
                        id: fullId,
                        size: dirSize > 0 ? dirSize : nil,
                        parameterSize: info.parameterSize,
                        quantization: Self.extractQuantization(from: modelName),
                        family: info.family,
                        source: .mlx
                    ))
                }
            }
            return results
        }.value
    }

    /// Reads config.json for a specific cached model to extract detailed info.
    public func getModelInfo(modelId: String) async -> ModelInfo? {
        let injectedBase = cacheBase
        return await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let resolvedBase: URL
            if let base = injectedBase {
                resolvedBase = base
            } else {
                guard let computed = fm.urls(for: .cachesDirectory, in: .userDomainMask)
                    .first?.appendingPathComponent("models") else { return nil }
                resolvedBase = computed
            }

            let configURL = resolvedBase.appendingPathComponent(modelId)
                .appendingPathComponent("config.json")
            guard let data = try? Data(contentsOf: configURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                return nil
            }

            let contextLength = json["max_position_embeddings"] as? Int
                ?? json["sliding_window"] as? Int

            return ModelInfo(
                contextLength: contextLength,
                parameters: json.compactMapValues { "\($0)" }
            )
        }.value
    }

    // MARK: - Private

    private struct ConfigInfo {
        let parameterSize: String?
        let family: String?
    }

    private static func parseConfig(data: Data) -> ConfigInfo {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ConfigInfo(parameterSize: nil, family: nil)
        }

        let family = json["model_type"] as? String
        var paramSize: String? = nil
        // Transformer parameter count ≈ 4 · hidden² · layers (attention + FFN weight matrices
        // dominate; ignores embeddings). Accurate to ~10-20% for typical decoder models.
        if let hidden = json["hidden_size"] as? Int,
           let layers = json["num_hidden_layers"] as? Int
        {
            let approxParams = Double(hidden * hidden * layers * 4) / 1_000_000_000
            if approxParams >= 1.0 {
                paramSize = "\(Int(approxParams.rounded()))B"
            } else {
                paramSize = "\(Int(approxParams * 1000))M"
            }
        }

        return ConfigInfo(parameterSize: paramSize, family: family)
    }

    private static func extractQuantization(from name: String) -> String? {
        let lower = name.lowercased()
        if lower.contains("4bit") || lower.contains("4-bit") { return "4-bit" }
        if lower.contains("8bit") || lower.contains("8-bit") { return "8-bit" }
        if lower.contains("fp16") { return "FP16" }
        return nil
    }

    /// Sum of allocated file sizes under `url`, using
    /// `.totalFileAllocatedSizeKey` per-file so the walk returns quickly even
    /// on multi-GB model directories with many shards.
    private static func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(
                forKeys: [.totalFileAllocatedSizeKey]
            ))?.totalFileAllocatedSize ?? 0
            total += Int64(size)
        }
        return total
    }
}
