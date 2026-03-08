import Foundation
import MLX
@preconcurrency import MLXLMCommon
import MLXLLM
import MLXOptimizers
import SwiftClawCore

/// Configuration for a LoRA fine-tuning run.
/// All defaults live in `init` — properties have no per-property defaults to avoid two sources of truth.
public struct LoRATrainingConfig: Sendable {
    public var name: String
    public var modelId: String
    public var numLayers: Int
    public var rank: Int
    public var scale: Float
    public var batchSize: Int
    public var iterations: Int
    public var learningRate: Float
    public var validationSplit: Float
    public var stepsPerReport: Int
    public var stepsPerEval: Int
    public var saveEvery: Int
    public var tags: [String]
    public var description: String?

    public init(
        name: String,
        modelId: String = SwiftClawVersion.defaultModelId,
        numLayers: Int = 8,
        rank: Int = 8,
        scale: Float = 10.0,
        batchSize: Int = 1,
        iterations: Int = 100,
        learningRate: Float = 1e-5,
        validationSplit: Float = 0.1,
        stepsPerReport: Int = 10,
        stepsPerEval: Int = 50,
        saveEvery: Int = 50,
        tags: [String] = [],
        description: String? = nil
    ) {
        self.name = name
        self.modelId = modelId
        self.numLayers = numLayers
        self.rank = rank
        self.scale = scale
        self.batchSize = batchSize
        self.iterations = iterations
        self.learningRate = learningRate
        self.validationSplit = validationSplit
        self.stepsPerReport = stepsPerReport
        self.stepsPerEval = stepsPerEval
        self.saveEvery = saveEvery
        self.tags = tags
        self.description = description
    }
}

/// Progress events emitted during training.
public enum TrainingProgress: Sendable {
    case started(sessions: Int, trainSamples: Int, validSamples: Int)
    case step(iteration: Int, trainingLoss: Float, tokensPerSecond: Double)
    case validation(iteration: Int, validationLoss: Float)
    case saved(iteration: Int, url: URL)
    case finished(adapterURL: URL, finalTrainingLoss: Float?, finalValidationLoss: Float?)
}

/// Drives LoRA fine-tuning from SwiftClaw session message batches.
public struct LoRATrainer: Sendable {

    public init() {}

    /// Convenience: load a model from `config.modelId` then train.
    public func train(
        sessions: [[SwiftClawCore.Message]],
        config: LoRATrainingConfig,
        store: AdapterStore,
        progress: @Sendable @escaping (TrainingProgress) -> Void
    ) async throws {
        let modelContainer = try await loadModelContainer(
            configuration: ModelConfiguration(id: config.modelId),
            progressHandler: { _ in }
        )
        try await train(
            modelContainer: modelContainer,
            sessions: sessions,
            config: config,
            store: store,
            progress: progress
        )
    }

    /// Train a LoRA adapter from session message batches.
    ///
    /// - Parameters:
    ///   - modelContainer: A loaded `ModelContainer`.
    ///   - sessions: Message batches — one array of `Message` per session.
    ///   - config: Training hyperparameters and metadata.
    ///   - store: Adapter storage; adapter directory must not already exist.
    ///   - progress: Callback receiving `TrainingProgress` events.
    public func train(
        modelContainer: ModelContainer,
        sessions: [[SwiftClawCore.Message]],
        config: LoRATrainingConfig,
        store: AdapterStore,
        progress: @Sendable @escaping (TrainingProgress) -> Void
    ) async throws {

        // Guard: adapter must not already exist
        guard !store.exists(name: config.name) else {
            throw SwiftClawError.trainingFailed("Adapter '\(config.name)' already exists. Delete it first.")
        }

        // Filter messages: keep only system/user/assistant with text content
        let textSessions = sessions.compactMap { messages -> [SwiftClawCore.Message]? in
            let filtered = messages.filter { msg in
                switch msg.role {
                case .system, .user:
                    return true
                case .assistant:
                    // Drop tool-call turns and empty assistant messages
                    return msg.toolCalls == nil && !msg.content.isEmpty
                case .tool:
                    return false
                }
            }
            return filtered.count >= 2 ? filtered : nil
        }

        guard !textSessions.isEmpty else {
            throw SwiftClawError.insufficientTrainingData(
                "No sessions have enough text-only turns for training (need ≥2 turns after filtering tool calls)."
            )
        }

        // Convert sessions to flat training strings via chat template
        let trainingStrings = try await modelContainer.perform { context in
            try textSessions.compactMap { messages -> String? in
                let chatMessages = messages.map { msg -> [String: String] in
                    ["role": msg.role.rawValue, "content": msg.content]
                }
                let tokens = try context.tokenizer.applyChatTemplate(messages: chatMessages)
                return context.tokenizer.decode(tokens: tokens)
            }
        }

        guard !trainingStrings.isEmpty else {
            throw SwiftClawError.insufficientTrainingData("Chat template produced no training strings.")
        }

        // Split train/validation
        let (trainData, validData) = split(trainingStrings, validationFraction: config.validationSplit)

        if validData.isEmpty {
            fputs("Warning: not enough sessions for a validation split — using all data for training.\n", stderr)
        }

        progress(.started(sessions: textSessions.count, trainSamples: trainData.count, validSamples: validData.count))

        // Create adapter output directory; remove it on failure to avoid blocking retries.
        let adapterDir = try store.adapterURL(name: config.name)
        try FileManager.default.createDirectory(at: adapterDir, withIntermediateDirectories: true)
        var committed = false
        defer {
            if !committed {
                try? FileManager.default.removeItem(at: adapterDir)
            }
        }

        // Build LoRA config once — reused for both training and adapter_config.json.
        let loraConfig = LoRAConfiguration(
            numLayers: config.numLayers,
            fineTuneType: .lora,
            loraParameters: LoRAConfiguration.LoRAParameters(rank: config.rank, scale: config.scale)
        )

        // Training runs entirely inside modelContainer.perform.
        // Return loss values instead of mutating captured vars (Swift 6 @Sendable closure restriction).
        let (finalTrainLoss, finalValidLoss): (Float?, Float?) = try await modelContainer.perform { context in
            let adapter = try LoRAContainer.from(model: context.model, configuration: loraConfig)
            try adapter.load(into: context.model)

            let optimizer = Adam(learningRate: config.learningRate)
            let trainParams = LoRATrain.Parameters(
                batchSize: config.batchSize,
                iterations: config.iterations,
                stepsPerReport: config.stepsPerReport,
                stepsPerEval: config.stepsPerEval,
                validationBatches: max(1, validData.count),
                saveEvery: config.saveEvery,
                adapterURL: adapterDir
            )

            var lastTrainLoss: Float? = nil
            var lastValidLoss: Float? = nil

            try LoRATrain.train(
                model: context.model,
                train: trainData,
                validate: validData.isEmpty ? trainData : validData,
                optimizer: optimizer,
                tokenizer: context.tokenizer,
                parameters: trainParams
            ) { loraProgress in
                switch loraProgress {
                case let .train(iteration, trainingLoss, _, tokensPerSecond):
                    lastTrainLoss = trainingLoss
                    progress(.step(iteration: iteration, trainingLoss: trainingLoss, tokensPerSecond: tokensPerSecond))
                case let .validation(iteration, validationLoss, _):
                    lastValidLoss = validationLoss
                    progress(.validation(iteration: iteration, validationLoss: validationLoss))
                case let .save(iteration, url):
                    progress(.saved(iteration: iteration, url: url))
                }
                return .more
            }
            return (lastTrainLoss, lastValidLoss)
        }

        // Save adapter_config.json (required by LoRAContainer.from(directory:) at inference time)
        let configEncoder = JSONEncoder()
        configEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let configData = try configEncoder.encode(loraConfig)
        try configData.write(to: adapterDir.appending(path: "adapter_config.json"), options: .atomic)

        // Save metadata
        let metadata = AdapterMetadata(
            name: config.name,
            modelId: config.modelId,
            createdAt: Date(),
            iterations: config.iterations,
            rank: config.rank,
            numLayers: config.numLayers,
            finalTrainingLoss: finalTrainLoss,
            finalValidationLoss: finalValidLoss,
            sessionCount: textSessions.count,
            tags: config.tags,
            description: config.description
        )
        try store.saveMetadata(metadata)
        committed = true

        progress(.finished(adapterURL: adapterDir, finalTrainingLoss: finalTrainLoss, finalValidationLoss: finalValidLoss))
    }

    // MARK: - Private helpers

    private func split(_ data: [String], validationFraction: Float) -> (train: [String], valid: [String]) {
        guard data.count >= 2, validationFraction > 0 else {
            return (data, [])
        }
        let validCount = max(1, Int((Float(data.count) * validationFraction).rounded()))
        guard data.count - validCount >= 1 else {
            return (data, [])
        }
        let shuffled = data.shuffled()
        let splitIdx = shuffled.count - validCount
        return (Array(shuffled[..<splitIdx]), Array(shuffled[splitIdx...]))
    }
}
