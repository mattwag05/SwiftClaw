import ArgumentParser
import Foundation
import SwiftClawCore
import SwiftClawMLX

struct TrainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "train",
        abstract: "Fine-tune a LoRA adapter from saved agent sessions."
    )

    @Option(name: .long, help: "Name for the trained adapter.")
    var name: String

    @Option(name: .long, help: "Model ID to train (Hugging Face, must match cached model).")
    var model: String = SwiftClawVersion.defaultModelId

    @Option(name: .long, help: "Comma-separated session IDs to train on.")
    var sessions: String?

    @Flag(help: "Train on all saved sessions.")
    var all: Bool = false

    @Option(name: .long, help: "Skip sessions with fewer than N messages.")
    var minMessages: Int = 2

    @Option(name: .long, help: "Number of LoRA adapter layers.")
    var numLayers: Int = 8

    @Option(name: .long, help: "LoRA rank.")
    var rank: Int = 8

    @Option(name: .long, help: "Number of training iterations.")
    var iterations: Int = 100

    @Option(name: .long, help: "Learning rate for Adam optimizer.")
    var learningRate: Float = 1e-5

    @Option(name: .long, help: "Training batch size.")
    var batchSize: Int = 1

    mutating func run() async throws {
        // Validate inputs
        guard sessions != nil || all else {
            fputs("Error: provide --sessions <ids> or --all.\n", stderr)
            throw ExitCode.failure
        }

        let store = try FileSessionStore()
        var batches: [[Message]] = []

        if all {
            let summaries = try await store.list()
            for summary in summaries {
                guard summary.messageCount >= minMessages else { continue }
                do {
                    let (msgs, _) = try await store.load(sessionId: summary.sessionId)
                    batches.append(msgs)
                } catch {
                    fputs("Warning: skipping session '\(summary.sessionId)': \(error.localizedDescription)\n", stderr)
                }
            }
        } else if let ids = sessions {
            for id in ids.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) {
                do {
                    let (msgs, _) = try await store.load(sessionId: id)
                    guard msgs.count >= minMessages else {
                        fputs("Warning: skipping session '\(id)' (only \(msgs.count) messages, need \(minMessages)).\n", stderr)
                        continue
                    }
                    batches.append(msgs)
                } catch {
                    fputs("Warning: skipping session '\(id)': \(error.localizedDescription)\n", stderr)
                }
            }
        }

        guard !batches.isEmpty else {
            fputs("Error: no sessions loaded. Check session IDs or lower --min-messages.\n", stderr)
            throw ExitCode.failure
        }

        fputs("Loaded \(batches.count) session(s).\n", stderr)

        let adapterStore = try AdapterStore()
        guard !adapterStore.exists(name: name) else {
            fputs("Error: adapter '\(name)' already exists. Delete it with 'swiftclaw adapters delete \(name)' first.\n", stderr)
            throw ExitCode.failure
        }

        let config = LoRATrainingConfig(
            name: name,
            modelId: model,
            numLayers: numLayers,
            rank: rank,
            batchSize: batchSize,
            iterations: iterations,
            learningRate: learningRate
        )

        fputs("Loading model: \(model)...\n", stderr)
        let trainer = LoRATrainer()
        try await trainer.train(
            sessions: batches,
            config: config,
            store: adapterStore
        ) { event in
            switch event {
            case let .started(sessions, trainSamples, validSamples):
                fputs("Model loaded.\n", stderr)
                fputs("Training: \(sessions) session(s), \(trainSamples) train / \(validSamples) valid samples.\n", stderr)
            case let .step(iteration, trainingLoss, tokensPerSecond):
                fputs("  Step \(iteration): loss=\(String(format: "%.4f", trainingLoss))  \(String(format: "%.1f", tokensPerSecond)) tok/s\n", stderr)
            case let .validation(iteration, validationLoss):
                fputs("  Eval  \(iteration): val_loss=\(String(format: "%.4f", validationLoss))\n", stderr)
            case let .saved(iteration, url):
                fputs("  Saved checkpoint at step \(iteration): \(url.path)\n", stderr)
            case let .finished(adapterURL, finalTrainLoss, finalValidLoss):
                fputs("Training complete.\n", stderr)
                if let tl = finalTrainLoss { fputs("  Final train loss: \(String(format: "%.4f", tl))\n", stderr) }
                if let vl = finalValidLoss { fputs("  Final val loss:   \(String(format: "%.4f", vl))\n", stderr) }
                print(adapterURL.path)
            }
        }
    }
}
