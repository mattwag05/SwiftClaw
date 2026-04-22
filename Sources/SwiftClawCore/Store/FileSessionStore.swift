import Foundation

/// JSON file-based session store.
/// Saves each session as `~/.swiftclaw/sessions/<sessionId>.json`.
public actor FileSessionStore: SessionStore {
    private let sessionsDir: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(baseDir: URL? = nil) throws {
        let base = baseDir ?? FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".swiftclaw")
        sessionsDir = base.appendingPathComponent("sessions")
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        encoder = enc
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        decoder = dec
        try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
    }

    // Whitelist: only alphanumeric, hyphen, underscore, and period allowed.
    // This prevents newline injection, null bytes, path separators, and
    // other special characters that could cause unexpected filesystem behavior.
    private static let allowedSessionIdChars = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "-_."))

    private func sanitize(sessionId: String) throws {
        guard !sessionId.isEmpty,
              sessionId.count <= 100,
              sessionId.unicodeScalars.allSatisfy({ Self.allowedSessionIdChars.contains($0) })
        else {
            throw SwiftClawError.storageError("Invalid session ID")
        }
    }

    public func save(sessionId: String, messages: [Message], metadata: SessionMetadata) async throws {
        try sanitize(sessionId: sessionId)
        let record = SessionRecord(metadata: metadata, messages: messages)
        let data = try encoder.encode(record)
        let file = sessionsDir.appendingPathComponent("\(sessionId).json")
        do {
            try data.write(to: file, options: .atomic)
        } catch {
            throw SwiftClawError.storageError("Write failed: \(error.localizedDescription)")
        }
    }

    public func load(sessionId: String) async throws -> (messages: [Message], metadata: SessionMetadata) {
        try sanitize(sessionId: sessionId)
        let file = sessionsDir.appendingPathComponent("\(sessionId).json")
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw SwiftClawError.sessionNotFound(sessionId)
        }
        do {
            let data = try Data(contentsOf: file)
            let record = try decoder.decode(SessionRecord.self, from: data)
            return (record.messages, record.metadata)
        } catch let error as SwiftClawError {
            throw error
        } catch {
            throw SwiftClawError.storageError("Read failed: \(error.localizedDescription)")
        }
    }

    public func list() async throws -> [SessionSummary] {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: sessionsDir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }
        } catch {
            return []
        }

        let dec = decoder
        return files.compactMap { file -> SessionSummary? in
            guard
                let data = try? Data(contentsOf: file),
                let record = try? dec.decode(SessionRecord.self, from: data)
            else { return nil }
            let sessionId = file.deletingPathExtension().lastPathComponent
            let firstUserMessage = record.messages.first(where: { $0.role == .user })?.content ?? ""
            let preview = String(firstUserMessage.prefix(80))
            let meta = record.metadata
            return SessionSummary(
                sessionId: sessionId,
                agentName: meta.agentName,
                messageCount: record.messages.count,
                updatedAt: meta.updatedAt,
                preview: preview,
                title: meta.title,
                isPinned: meta.isPinned,
                pinnedAt: meta.pinnedAt,
                folderID: meta.folderID,
                tags: meta.tags
            )
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func updateMetadata(
        sessionId: String,
        _ transform: @Sendable (inout SessionMetadata) -> Void
    ) async throws {
        try sanitize(sessionId: sessionId)
        let file = sessionsDir.appendingPathComponent("\(sessionId).json")
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw SwiftClawError.sessionNotFound(sessionId)
        }
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch {
            throw SwiftClawError.storageError("Read failed: \(error.localizedDescription)")
        }
        var record = try decoder.decode(SessionRecord.self, from: data)
        transform(&record.metadata)
        let newData = try encoder.encode(record)
        do {
            try newData.write(to: file, options: .atomic)
        } catch {
            throw SwiftClawError.storageError("Write failed: \(error.localizedDescription)")
        }
    }

    public func delete(sessionId: String) async throws {
        try sanitize(sessionId: sessionId)
        let file = sessionsDir.appendingPathComponent("\(sessionId).json")
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw SwiftClawError.sessionNotFound(sessionId)
        }
        do {
            try FileManager.default.removeItem(at: file)
        } catch {
            throw SwiftClawError.storageError("Delete failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Private

private struct SessionRecord: Codable {
    var metadata: SessionMetadata
    let messages: [Message]
}
