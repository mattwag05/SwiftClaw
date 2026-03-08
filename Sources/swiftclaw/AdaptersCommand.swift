import ArgumentParser
import Foundation
import SwiftClawMLX

struct AdaptersCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "adapters",
        abstract: "Manage trained LoRA adapters.",
        subcommands: [ListCommand.self, DeleteCommand.self, TagCommand.self]
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
                if !adapter.tags.isEmpty {
                    print("  tags: \(adapter.tags.joined(separator: ", "))")
                }
                if let desc = adapter.description {
                    print("  desc: \(desc)")
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

    struct TagCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "tag",
            abstract: "Add or remove tags on a trained adapter."
        )

        @Argument(help: "Adapter name.")
        var name: String

        @Option(name: .long, help: "Comma-separated tags to add.")
        var add: String?

        @Option(name: .long, help: "Comma-separated tags to remove.")
        var remove: String?

        mutating func run() async throws {
            let store = try AdapterStore()
            var meta = try store.loadMetadata(name: name)

            if let toAdd = add {
                let newTags = parseTags(toAdd)
                for tag in newTags where !meta.tags.contains(tag) {
                    meta.tags.append(tag)
                }
            }
            if let toRemove = remove {
                let dropTags = Set(parseTags(toRemove))
                meta.tags = meta.tags.filter { !dropTags.contains($0) }
            }

            try store.saveMetadata(meta)
            if meta.tags.isEmpty {
                print("'\(name)' tags cleared.")
            } else {
                print("'\(name)' tags: \(meta.tags.joined(separator: ", "))")
            }
        }
    }
}

