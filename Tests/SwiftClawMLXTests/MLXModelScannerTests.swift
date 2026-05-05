import Foundation
import SwiftClawCore
@testable import SwiftClawMLX
import Testing

// MARK: - Helpers

private func makeFixtureCache() throws -> URL {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("mlx-scanner-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    return tmp
}

private func addModel(
    _ cacheBase: URL,
    org: String,
    name: String,
    config: [String: Any]
) throws {
    let dir = cacheBase.appendingPathComponent(org).appendingPathComponent(name)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let data = try JSONSerialization.data(withJSONObject: config)
    try data.write(to: dir.appendingPathComponent("config.json"))
}

// MARK: - Tests

@Suite("MLXModelScanner Tests")
struct MLXModelScannerTests {
    @Test("Discovers model with config.json and infers fields")
    func discoversModelWithConfig() async throws {
        let cache = try makeFixtureCache()
        defer { try? FileManager.default.removeItem(at: cache) }

        try addModel(cache, org: "mlx-community", name: "Qwen3.5-9B-MLX-4bit", config: [
            "model_type": "qwen2",
            "hidden_size": 4096,
            "num_hidden_layers": 32,
        ])

        let models = await MLXModelScanner(cacheBase: cache).listCachedModels()

        #expect(models.count == 1)
        let m = models[0]
        #expect(m.id == "mlx-community/Qwen3.5-9B-MLX-4bit")
        #expect(m.source == .mlx)
        #expect(m.family == "qwen2")
        #expect(m.quantization == "4-bit")
        #expect(m.parameterSize != nil)
    }

    @Test("Infers 4-bit quantization from model name")
    func infersFourBitQuant() async throws {
        let cache = try makeFixtureCache()
        defer { try? FileManager.default.removeItem(at: cache) }

        try addModel(cache, org: "org", name: "Model-4bit", config: ["model_type": "llama"])

        let models = await MLXModelScanner(cacheBase: cache).listCachedModels()
        #expect(models.first?.quantization == "4-bit")
    }

    @Test("Infers 8-bit quantization from model name")
    func infersEightBitQuant() async throws {
        let cache = try makeFixtureCache()
        defer { try? FileManager.default.removeItem(at: cache) }

        try addModel(cache, org: "org", name: "Model-8bit", config: ["model_type": "llama"])

        let models = await MLXModelScanner(cacheBase: cache).listCachedModels()
        #expect(models.first?.quantization == "8-bit")
    }

    @Test("Skips directories without config.json")
    func skipsNoConfig() async throws {
        let cache = try makeFixtureCache()
        defer { try? FileManager.default.removeItem(at: cache) }

        let emptyDir = cache.appendingPathComponent("org").appendingPathComponent("no-config")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        let models = await MLXModelScanner(cacheBase: cache).listCachedModels()
        #expect(models.isEmpty)
    }

    @Test("Returns empty array for empty cache directory")
    func emptyCache() async throws {
        let cache = try makeFixtureCache()
        defer { try? FileManager.default.removeItem(at: cache) }

        let models = await MLXModelScanner(cacheBase: cache).listCachedModels()
        #expect(models.isEmpty)
    }

    @Test("Returns empty array when cache directory does not exist")
    func nonExistentCache() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString)")
        let models = await MLXModelScanner(cacheBase: missing).listCachedModels()
        #expect(models.isEmpty)
    }

    @Test("Discovers multiple models across multiple orgs")
    func multipleModels() async throws {
        let cache = try makeFixtureCache()
        defer { try? FileManager.default.removeItem(at: cache) }

        try addModel(cache, org: "mlx-community", name: "ModelA-4bit", config: ["model_type": "llama"])
        try addModel(cache, org: "mlx-community", name: "ModelB-fp16", config: ["model_type": "qwen2"])
        try addModel(cache, org: "other-org", name: "ModelC", config: [:])

        let models = await MLXModelScanner(cacheBase: cache).listCachedModels()
        #expect(models.count == 3)

        let ids = Set(models.map(\.id))
        #expect(ids.contains("mlx-community/ModelA-4bit"))
        #expect(ids.contains("mlx-community/ModelB-fp16"))
        #expect(ids.contains("other-org/ModelC"))
    }

    @Test("Computes directory size")
    func computesSize() async throws {
        let cache = try makeFixtureCache()
        defer { try? FileManager.default.removeItem(at: cache) }

        let dir = cache.appendingPathComponent("org").appendingPathComponent("BigModel")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let config = ["model_type": "llama"]
        try JSONSerialization.data(withJSONObject: config)
            .write(to: dir.appendingPathComponent("config.json"))

        let payload = Data(repeating: 0x00, count: 1024)
        try payload.write(to: dir.appendingPathComponent("weights.safetensors"))

        let models = await MLXModelScanner(cacheBase: cache).listCachedModels()
        #expect((models.first?.size ?? 0) > 0)
    }
}
