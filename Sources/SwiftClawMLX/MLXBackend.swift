import Foundation
import MLX
@preconcurrency import MLXLMCommon
import MLXLLM
import SwiftClawCore

/// MLX-native model backend using mlx-swift-lm for on-device inference.
public final class MLXBackend: ModelBackend, @unchecked Sendable {
    private let modelContainer: ModelContainer

    /// Load a model and create the backend.
    ///
    /// - Parameters:
    ///   - modelId: Hugging Face model ID (e.g. "mlx-community/Qwen3.5-9B-MLX-4bit")
    ///   - progressHandler: Optional callback for download progress
    public init(
        modelId: String,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws {
        do {
            let configuration = ModelConfiguration(id: modelId)
            self.modelContainer = try await loadModelContainer(
                configuration: configuration,
                progressHandler: progressHandler ?? { _ in }
            )
        } catch {
            throw SwiftClawError.modelLoadFailed("\(modelId): \(error.localizedDescription)")
        }
    }

    /// Create from an existing ModelContainer.
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    public nonisolated func generate(
        messages: [SwiftClawCore.Message],
        tools: [ToolDefinition],
        config: GenerationConfig
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        let (stream, continuation) = AsyncThrowingStream<StreamChunk, Error>.makeStream()

        let modelContainer = self.modelContainer
        let chatMessages = MLXToolBridge.toChatMessages(messages)
        // Text-injection strategy: tools are appended to the system message as plain text
        // rather than passed via UserInput.tools. The template tool mechanism causes the model
        // to stop at EOS after </think> without generating a tool call.
        let chatWithTools = tools.isEmpty
            ? chatMessages
            : MLXToolBridge.injectToolsIntoSystemMessage(chatMessages, tools: tools)

        Task { @Sendable in
            do {
                try await Self.runGeneration(
                    modelContainer: modelContainer,
                    chatMessages: chatWithTools,
                    config: config,
                    continuation: continuation
                )
            } catch {
                continuation.finish(throwing: SwiftClawError.generationFailed(error.localizedDescription))
            }
        }

        return stream
    }

    private static func runGeneration(
        modelContainer: ModelContainer,
        chatMessages: [Chat.Message],
        config: GenerationConfig,
        continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation
    ) async throws {

        let userInput = UserInput(chat: chatMessages)

        let lmInput = try await modelContainer.prepare(input: userInput)

        var generateParams = GenerateParameters()
        generateParams.maxTokens = config.maxTokens
        generateParams.temperature = config.temperature
        if let topP = config.topP { generateParams.topP = topP }

        let generationStream = try await modelContainer.generate(
            input: lmInput,
            parameters: generateParams
        )

        var collectedToolCalls: [ToolCallRequest] = []
        var accumulatedText = ""

        for await generation in generationStream {
            switch generation {
            case let .chunk(text):
                accumulatedText += text
                continuation.yield(StreamChunk(text: text))

            case let .toolCall(toolCall):
                let request = MLXToolBridge.toToolCallRequest(toolCall)
                collectedToolCalls.append(request)

            case let .info(info):
                // Fallback: parse tool call XML from text.
                // Handles <tool_call>...</tool_call> (template format) and
                // bare <function=name>...</function> (text-injection format).
                if collectedToolCalls.isEmpty &&
                    (accumulatedText.contains("<tool_call>") || accumulatedText.contains("<function="))
                {
                    let parsed = Qwen35ToolCallParser.parse(text: accumulatedText)
                    collectedToolCalls = parsed.toolCalls
                }

                let reason: StreamChunk.FinishReason
                if !collectedToolCalls.isEmpty {
                    reason = .toolCall
                } else if info.stopReason == GenerateStopReason.length {
                    reason = .length
                } else {
                    reason = .stop
                }

                continuation.yield(StreamChunk(
                    toolCalls: collectedToolCalls.isEmpty ? nil : collectedToolCalls,
                    finishReason: reason
                ))
            }
        }

        continuation.finish()
    }
}

/// Load model convenience function with SwiftClaw error handling.
public func loadMLXBackend(
    modelId: String,
    onProgress: (@Sendable (Double) -> Void)? = nil
) async throws -> MLXBackend {
    try await MLXBackend(modelId: modelId) { progress in
        onProgress?(progress.fractionCompleted)
    }
}
