import ArgumentParser
import Foundation
import SwiftClawCore
import SwiftClawMLX

struct EvalCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "eval",
        abstract: "Side-by-side A/B evaluation of base model vs a LoRA adapter (or two adapters)."
    )

    @Argument(help: "Prompt to evaluate.")
    var prompt: String

    @Option(name: .long, help: "Name of the adapter to use as side B (required).")
    var adapterB: String

    @Option(name: .long, help: "Name of the adapter for side A (default: base model, no adapter).")
    var adapterA: String?

    @Option(name: .long, help: "Model ID to load.")
    var model: String = SwiftClawVersion.defaultModelId

    @Option(name: .long, help: "Maximum tokens per response.")
    var maxTokens: Int = 1024

    mutating func run() async throws {
        let adapterStore = try AdapterStore()

        // Validate existence before resolving URLs
        if let name = adapterA, !adapterStore.exists(name: name) {
            fputs("Error: adapter '\(name)' not found.\n", stderr)
            throw ExitCode.failure
        }
        guard adapterStore.exists(name: adapterB) else {
            fputs("Error: adapter '\(adapterB)' not found.\n", stderr)
            throw ExitCode.failure
        }

        let urlA: URL? = try adapterA.map { try adapterStore.adapterURL(name: $0) }
        let urlB: URL = try adapterStore.adapterURL(name: adapterB)

        let labelA = adapterA ?? "base model"

        print("Eval: \"\(prompt)\"")
        print("  Side A: \(labelA)")
        print("  Side B: \(adapterB)")
        print(String(repeating: "─", count: 60))

        // --- Side A ---
        print("\nGenerating response A (\(labelA))...")
        let responseA = try await generate(prompt: prompt, modelId: model, adapterURL: urlA, maxTokens: maxTokens)
        print("\n── Response A (\(labelA)) ──")
        print(responseA)

        // --- Side B ---
        print("\nGenerating response B (\(adapterB))...")
        let responseB = try await generate(prompt: prompt, modelId: model, adapterURL: urlB, maxTokens: maxTokens)
        print("\n── Response B (\(adapterB)) ──")
        print(responseB)

        // --- Winner ---
        print(String(repeating: "─", count: 60))
        print("Winner? [A/B/tie/skip]: ", terminator: "")
        fflush(stdout)
        let input = readLine(strippingNewline: true)?.trimmingCharacters(in: .whitespaces).lowercased() ?? "skip"
        let winner: EvalResult.Winner = switch input {
            case "a":    .a
            case "b":    .b
            case "tie":  .tie
            default:     .skip
        }

        let result = EvalResult(
            modelId: model,
            adapterA: adapterA,
            adapterB: adapterB,
            prompt: prompt,
            responseA: responseA,
            responseB: responseB,
            winner: winner
        )
        let evalStore = try EvalStore()
        try evalStore.save(result)
        print("Recorded: \(winner.rawValue). Saved to \(evalStore.evalsURL.path)")
    }

    // MARK: - Single-turn generation helper

    // Note: each call loads the full model (~5 GB). The two sides run sequentially so ARC
    // releases the first backend before the second loads. On 24 GB M4 this is fine.
    private func generate(prompt: String, modelId: String, adapterURL: URL?, maxTokens: Int) async throws -> String {
        let backend = try await loadMLXBackend(modelId: modelId, adapterPath: adapterURL) { _ in }
        let systemPrompt = "You are a helpful assistant."
        let genConfig = GenerationConfig(maxTokens: maxTokens)
        let messages: [Message] = [
            Message(role: .system, content: systemPrompt),
            Message(role: .user, content: prompt)
        ]
        let response = try await backend.generate(messages: messages, tools: [], config: genConfig)
        return response.content
    }
}
