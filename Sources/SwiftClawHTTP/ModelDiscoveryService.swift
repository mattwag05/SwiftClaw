import Foundation
import SwiftClawCore

/// Discovers available models from Ollama or OpenAI-compatible APIs.
public struct ModelDiscoveryService: Sendable {

    public init() {}

    // MARK: - Ollama

    /// Lists locally installed Ollama models via `GET /api/tags`.
    /// `baseURL` should be the Ollama-compatible endpoint (e.g. `http://localhost:11434/v1`).
    /// The `/v1` suffix is stripped automatically.
    public func listOllamaModels(baseURL: URL) async throws -> [DiscoveredModel] {
        let tagsURL = Self.ollamaBaseURL(from: baseURL).appendingPathComponent("api/tags")

        var request = URLRequest(url: tagsURL, timeoutInterval: 10)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw ModelDiscoveryError.requestFailed
        }

        let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return decoded.models.map { model in
            DiscoveredModel(
                id: model.name,
                size: model.size,
                parameterSize: model.details?.parameterSize,
                quantization: model.details?.quantizationLevel,
                family: model.details?.family,
                source: .ollama
            )
        }
    }

    /// Fetches detailed model info from Ollama via `POST /api/show`.
    public func getOllamaModelInfo(baseURL: URL, model: String) async throws -> ModelInfo {
        let showURL = Self.ollamaBaseURL(from: baseURL).appendingPathComponent("api/show")

        var request = URLRequest(url: showURL, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["name": model])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw ModelDiscoveryError.requestFailed
        }

        let decoded = try JSONDecoder().decode(OllamaShowResponse.self, from: data)
        return ModelInfo(
            contextLength: decoded.extractContextLength(),
            temperature: decoded.extractTemperature(),
            parameters: decoded.parsedParameters,
            template: decoded.template
        )
    }

    // MARK: - OpenAI-Compatible

    /// Lists models via `GET /v1/models` (works for OpenAI, proxies, etc.).
    public func listOpenAIModels(baseURL: URL, apiKey: String?) async throws -> [DiscoveredModel] {
        let modelsURL = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: modelsURL, timeoutInterval: 10)
        if let key = apiKey {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw ModelDiscoveryError.requestFailed
        }

        let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        return decoded.data.map { model in
            DiscoveredModel(id: model.id, source: .openai)
        }
    }

    // MARK: - Helpers

    /// Strips `/v1` or `/v1/` from the URL to get the Ollama base origin.
    private static func ollamaBaseURL(from url: URL) -> URL {
        var str = url.absoluteString
        if str.hasSuffix("/v1/") {
            str = String(str.dropLast(4))
        } else if str.hasSuffix("/v1") {
            str = String(str.dropLast(3))
        }
        return URL(string: str) ?? url
    }
}

// MARK: - Error

public enum ModelDiscoveryError: LocalizedError, Sendable {
    case invalidURL
    case requestFailed
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid discovery URL"
        case .requestFailed: return "Model discovery request failed"
        case .decodingFailed(let detail): return "Failed to decode response: \(detail)"
        }
    }
}

// MARK: - Ollama Response Types

struct OllamaTagsResponse: Decodable, Sendable {
    let models: [OllamaModel]
}

struct OllamaModel: Decodable, Sendable {
    let name: String
    let size: Int64?
    let details: OllamaModelDetails?
}

struct OllamaModelDetails: Decodable, Sendable {
    let family: String?
    let parameterSize: String?
    let quantizationLevel: String?

    enum CodingKeys: String, CodingKey {
        case family
        case parameterSize = "parameter_size"
        case quantizationLevel = "quantization_level"
    }
}

struct OllamaShowResponse: Decodable, Sendable {
    let parameters: String?
    let template: String?

    /// Parse newline-delimited "key value" pairs into a dictionary.
    var parsedParameters: [String: String] {
        guard let params = parameters else { return [:] }
        var dict: [String: String] = [:]
        for line in params.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            if parts.count == 2 {
                dict[String(parts[0])] = String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        return dict
    }

    func extractContextLength() -> Int? {
        if let raw = parsedParameters["num_ctx"], let val = Int(raw) {
            return val
        }
        return nil
    }

    func extractTemperature() -> Double? {
        if let raw = parsedParameters["temperature"], let val = Double(raw) {
            return val
        }
        return nil
    }
}

// MARK: - OpenAI Response Types

struct OpenAIModelsResponse: Decodable, Sendable {
    let data: [OpenAIModelEntry]
}

struct OpenAIModelEntry: Decodable, Sendable {
    let id: String
}
