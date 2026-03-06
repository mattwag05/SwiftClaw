import Foundation
import MLX
@preconcurrency import MLXLMCommon
import MLXLLM
import SwiftClawCore
import Tokenizers

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
        // Strategy: Don't pass tools via UserInput.tools (template tool mechanism broken for
        // this quantized model — model stops at </think>\n\n EOS before generating <tool_call>).
        // Instead, inject tool descriptions into the system message as text and parse
        // tool calls from the model's natural text generation.
        // Text-injection: Don't use template's tool mechanism (causes model to stop at EOS after think).
        // Instead, inject tool descriptions as text into system message and use enable_thinking:false
        // so the model skips the think block and generates the tool call directly.
        // Text-injection strategy: pass tools as system-message text (not via UserInput.tools).
        // Using UserInput.tools (template mechanism) causes the model to stop at </think>\n\n
        // without generating <tool_call>. Text-injection avoids this.
        // enable_thinking: false is passed when tools are present so the model skips the
        // think block and outputs the tool call or response directly.
        let toolSpecs: [ToolSpec]? = nil
        let hasTools = !tools.isEmpty
        let chatWithTools = hasTools
            ? MLXToolBridge.injectToolsIntoSystemMessage(chatMessages, tools: tools)
            : chatMessages
        // Keep thinking mode enabled; model generates think block then the tool call as text.
        let additionalCtx: [String: any Sendable]? = nil
        let maxTokens = config.maxTokens
        let temperature = config.temperature
        let topP = config.topP

        Task { @Sendable in
            do {
                try await Self.runGeneration(
                    modelContainer: modelContainer,
                    chatMessages: chatWithTools,
                    toolSpecs: toolSpecs,
                    additionalContext: additionalCtx,
                    maxTokens: maxTokens,
                    temperature: temperature,
                    topP: topP,
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
        toolSpecs: [ToolSpec]?,
        additionalContext: [String: any Sendable]?,
        maxTokens: Int,
        temperature: Float,
        topP: Float?,
        continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation
    ) async throws {

        let userInput = UserInput(
            chat: chatMessages,
            tools: toolSpecs,
            additionalContext: additionalContext
        )

        let lmInput = try await modelContainer.prepare(input: userInput)

        var generateParams = GenerateParameters()
        generateParams.maxTokens = maxTokens
        generateParams.temperature = temperature
        if let topP { generateParams.topP = topP }

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
