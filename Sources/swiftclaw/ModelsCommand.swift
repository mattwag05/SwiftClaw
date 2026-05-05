import ArgumentParser
import Foundation
import SwiftClawCore
import SwiftClawHTTP
import SwiftClawMLX

struct ModelsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "models",
        abstract: "Discover available models.",
        subcommands: [ListCommand.self]
    )

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List models from the MLX cache and HTTP backends."
        )

        enum BackendFilter: String, ExpressibleByArgument {
            case mlx, http, all
        }

        @Option(name: .long, help: "Filter by source: mlx, http, or all (default).")
        var backend: BackendFilter = .all

        @Option(name: .long, help: "Base URL for HTTP backend (default: http://localhost:11434/v1).")
        var apiUrl: String = "http://localhost:11434/v1"

        @Option(name: .long, help: "API key for HTTP backend (optional).")
        var apiKey: String?

        mutating func run() async throws {
            let models: [DiscoveredModel]

            switch backend {
            case .mlx:
                models = await MLXModelScanner().listCachedModels()
            case .http:
                guard let url = URL(string: apiUrl) else {
                    throw ValidationError("Invalid API URL: \(apiUrl)")
                }
                models = await discoverHTTP(url: url, apiKey: apiKey)
            case .all:
                guard let url = URL(string: apiUrl) else {
                    throw ValidationError("Invalid API URL: \(apiUrl)")
                }
                async let mlx = MLXModelScanner().listCachedModels()
                let http = await discoverHTTP(url: url, apiKey: apiKey)
                models = await mlx + http
            }

            if models.isEmpty {
                print("No models found.")
                return
            }

            print("\(col("ID", 48))  \(col("SRC", 6))  \(col("PARAMS", 8))  \(col("QUANT", 10))  SIZE")
            print(String(repeating: "-", count: 90))
            for m in models {
                let src = col(m.source.rawValue, 6)
                let params = col(m.parameterSize ?? "-", 8)
                let quant = col(m.quantization ?? "-", 10)
                let size = m.size.map { humanBytes($0) } ?? "-"
                print("\(col(m.id, 48))  \(src)  \(params)  \(quant)  \(size)")
            }
        }
    }
}

private func discoverHTTP(url: URL, apiKey: String?) async -> [DiscoveredModel] {
    let svc = ModelDiscoveryService()
    let host = url.host ?? ""
    let isLocal = host == "localhost" || host == "127.0.0.1" || host == "::1"
    do {
        return try await isLocal
            ? svc.listOllamaModels(baseURL: url)
            : svc.listOpenAIModels(baseURL: url, apiKey: apiKey)
    } catch {
        fputs("HTTP discovery failed (\(host)): \(error.localizedDescription)\n", stderr)
        return []
    }
}
