import Foundation
import SwiftClawCore

/// Metadata recorded alongside each trained LoRA adapter.
public struct AdapterMetadata: Codable, Sendable {
    public let name: String
    public let modelId: String
    public let createdAt: Date
    public let iterations: Int
    public let rank: Int
    public let numLayers: Int
    public let finalTrainingLoss: Float?
    public let finalValidationLoss: Float?
    public let sessionCount: Int

    public init(
        name: String,
        modelId: String,
        createdAt: Date = Date(),
        iterations: Int,
        rank: Int,
        numLayers: Int,
        finalTrainingLoss: Float? = nil,
        finalValidationLoss: Float? = nil,
        sessionCount: Int
    ) {
        self.name = name
        self.modelId = modelId
        self.createdAt = createdAt
        self.iterations = iterations
        self.rank = rank
        self.numLayers = numLayers
        self.finalTrainingLoss = finalTrainingLoss
        self.finalValidationLoss = finalValidationLoss
        self.sessionCount = sessionCount
    }
}

/// Manages adapter directories under `~/.swiftclaw/adapters/`.
public struct AdapterStore: Sendable {

    public let adaptersURL: URL

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    public init() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appending(path: ".swiftclaw/adapters", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.adaptersURL = dir
    }

    // MARK: - Directory URL

    /// URL of the directory for a given adapter name.
    /// Throws `storageError` if the name is invalid (empty, too long, contains `/`, `..`, or null bytes).
    public func adapterURL(name: String) throws -> URL {
        try validateName(name)
        return adaptersURL.appending(path: name, directoryHint: .isDirectory)
    }

    // MARK: - List

    public func list() throws -> [AdapterMetadata] {
        let entries = try FileManager.default.contentsOfDirectory(
            at: adaptersURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        return entries.compactMap { url -> AdapterMetadata? in
            let metaURL = url.appending(path: "metadata.json")
            guard let data = try? Data(contentsOf: metaURL) else { return nil }
            return try? Self.decoder.decode(AdapterMetadata.self, from: data)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Load metadata

    public func loadMetadata(name: String) throws -> AdapterMetadata {
        let metaURL = try adapterURL(name: name).appending(path: "metadata.json")
        do {
            let data = try Data(contentsOf: metaURL)
            return try Self.decoder.decode(AdapterMetadata.self, from: data)
        } catch let error as SwiftClawError {
            throw error
        } catch {
            throw SwiftClawError.adapterNotFound(name)
        }
    }

    // MARK: - Save metadata

    public func saveMetadata(_ metadata: AdapterMetadata) throws {
        let dir = try adapterURL(name: metadata.name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(metadata)
        let metaURL = dir.appending(path: "metadata.json")
        try data.write(to: metaURL, options: .atomic)
    }

    // MARK: - Delete

    public func delete(name: String) throws {
        let dir = try adapterURL(name: name)
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            throw SwiftClawError.adapterNotFound(name)
        }
    }

    // MARK: - Existence

    public func exists(name: String) -> Bool {
        guard let url = try? adapterURL(name: name) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Private helpers

    private func validateName(_ name: String) throws {
        guard !name.isEmpty,
              name.count <= 100,
              !name.contains("/"),
              !name.contains(".."),
              !name.contains("\0")
        else {
            throw SwiftClawError.storageError("Invalid adapter name: '\(name)'")
        }
    }
}
