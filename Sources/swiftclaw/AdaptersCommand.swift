import ArgumentParser
import Foundation
import SwiftClawMLX

struct AdaptersCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "adapters",
        abstract: "Manage trained LoRA adapters.",
        subcommands: [ListCommand.self, DeleteCommand.self]
    )

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all trained adapters."
        )

        mutating func run() async throws {
            let store = try AdapterStore()
            let adapters = try store.list()
            if adapters.isEmpty {
                print("No trained adapters.")
                return
            }
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            print("\(col("NAME", 24))  \(col("MODEL", 36))  \(col("ITERS", 6))  \(col("RANK", 4))  CREATED")
            print(String(repeating: "-", count: 90))
            for adapter in adapters {
                let date = formatter.string(from: adapter.createdAt)
                let iters = String(adapter.iterations).padding(toLength: 6, withPad: " ", startingAt: 0)
                let rank  = String(adapter.rank).padding(toLength: 4, withPad: " ", startingAt: 0)
                print("\(col(adapter.name, 24))  \(col(adapter.modelId, 36))  \(iters)  \(rank)  \(date)")
                if let tl = adapter.finalTrainingLoss {
                    let vl = adapter.finalValidationLoss.map { String(format: "  val=%.4f", $0) } ?? ""
                    print("  train_loss=\(String(format: "%.4f", tl))\(vl)  sessions=\(adapter.sessionCount)  layers=\(adapter.numLayers)")
                }
            }
        }
    }

    struct DeleteCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Delete a trained adapter."
        )

        @Argument(help: "Adapter name to delete.")
        var name: String

        mutating func run() async throws {
            let store = try AdapterStore()
            try store.delete(name: name)
            print("Deleted adapter '\(name)'.")
        }
    }
}
