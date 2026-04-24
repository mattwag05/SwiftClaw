import Foundation

/// Detailed info about a specific model, fetched after selection.
/// Populated from Ollama's `/api/show` or an MLX `config.json`.
public struct ModelInfo: Sendable {
    public let contextLength: Int?
    public let temperature: Double?
    public let parameters: [String: String]
    public let template: String?

    public init(
        contextLength: Int? = nil,
        temperature: Double? = nil,
        parameters: [String: String] = [:],
        template: String? = nil
    ) {
        self.contextLength = contextLength
        self.temperature = temperature
        self.parameters = parameters
        self.template = template
    }
}
