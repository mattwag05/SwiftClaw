import Foundation
import SwiftClawCore

/// An OpenAI-compatible HTTP backend for remote LLM inference.
///
/// Targets any server supporting the `/v1/chat/completions` endpoint with SSE streaming,
/// such as Ollama (`http://hostname:11434/v1`) or OpenAI (`https://api.openai.com/v1`).
public struct HTTPBackend: ModelBackend {
    private let endpoint: URL
    private let model: String
    private let apiKey: String?

    /// - Parameters:
    ///   - baseURL: Base URL of the API, e.g. `http://localhost:11434/v1`
    ///   - model: Model identifier sent in the request body
    ///   - apiKey: Optional Bearer token (not required for Ollama)
    public init(baseURL: URL, model: String, apiKey: String? = nil) {
        self.endpoint = baseURL.appendingPathComponent("chat/completions")
        self.model = model
        self.apiKey = apiKey
    }

    public func generate(
        messages: [Message],
        tools: [ToolDefinition],
        config: GenerationConfig
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await stream(
                        messages: messages,
                        tools: tools,
                        config: config,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Private

    private func stream(
        messages: [Message],
        tools: [ToolDefinition],
        config: GenerationConfig,
        continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation
    ) async throws {
        let request = try buildRequest(messages: messages, tools: tools, config: config)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SwiftClawError.generationFailed("Unexpected response type")
        }
        if !(200..<300).contains(http.statusCode) {
            var bodyBytes: [UInt8] = []
            for try await byte in bytes { bodyBytes.append(byte) }
            let body = String(bytes: bodyBytes, encoding: .utf8) ?? "<non-UTF-8 body>"
            throw SwiftClawError.httpRequestFailed(statusCode: http.statusCode, body: body)
        }

        let parser = SSEParser()
        // Accumulate tool call deltas: index → (id, name, arguments)
        var partials: [Int: (id: String, name: String, arguments: String)] = [:]
        var finishReason: StreamChunk.FinishReason = .stop

        for try await line in bytes.lines {
            let chunk: ChatCompletionChunk
            do {
                guard let c = try parser.parse(line: line) else { continue }
                chunk = c
            } catch is SSEDoneError {
                break
            } catch {
                throw SwiftClawError.sseParsingFailed(error.localizedDescription)
            }

            guard let choice = chunk.choices.first else { continue }

            // Emit text delta
            if let text = choice.delta.content, !text.isEmpty {
                continuation.yield(StreamChunk(text: text))
            }

            // Accumulate tool call deltas
            if let deltaToolCalls = choice.delta.toolCalls {
                for delta in deltaToolCalls {
                    let idx = delta.index
                    if var existing = partials[idx] {
                        if let args = delta.function?.arguments {
                            existing.arguments += args
                        }
                        partials[idx] = existing
                    } else {
                        partials[idx] = (
                            id: delta.id ?? UUID().uuidString,
                            name: delta.function?.name ?? "",
                            arguments: delta.function?.arguments ?? ""
                        )
                    }
                }
            }

            // Capture finish reason
            if let reason = choice.finishReason {
                switch reason {
                case "tool_calls": finishReason = .toolCall
                case "length":     finishReason = .length
                default:           finishReason = .stop
                }
            }
        }

        // Emit collected tool calls on the final chunk
        if !partials.isEmpty {
            let toolCalls = partials.sorted { $0.key < $1.key }.map { _, partial in
                ToolCallRequest(id: partial.id, name: partial.name, arguments: partial.arguments)
            }
            continuation.yield(StreamChunk(toolCalls: toolCalls, finishReason: finishReason))
        } else {
            continuation.yield(StreamChunk(finishReason: finishReason))
        }
    }

    private func buildRequest(
        messages: [Message],
        tools: [ToolDefinition],
        config: GenerationConfig
    ) throws -> URLRequest {
        let openAIMessages = messages.map { OpenAIMessage(from: $0) }
        let openAITools = tools.isEmpty ? nil : tools.map { OpenAIToolDefinition(from: $0) }

        let body = ChatCompletionRequest(
            model: model,
            messages: openAIMessages,
            tools: openAITools,
            stream: true,
            temperature: config.temperature,
            maxTokens: config.maxTokens,
            topP: config.topP
        )

        var request = URLRequest(url: endpoint, timeoutInterval: 300)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = apiKey {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}
