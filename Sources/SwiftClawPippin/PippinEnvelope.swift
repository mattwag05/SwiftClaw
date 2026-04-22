import Foundation

/// Envelope wrapper around `pippin <cmd> --format agent` output.
///
/// As of Pippin v0.20.0, every agent-format response is shaped as
/// ``{"v":1,"status":"ok"|"error","duration_ms":N,"data":<payload>?,"error":{code,message}?}``.
/// SwiftClaw parses it via ``parse(_:)``, surfaces ``data`` as a pretty-printed
/// JSON string for tool output, and turns ``error`` into a typed
/// ``PippinError/pippinError(code:message:)``.
public struct PippinEnvelope: Sendable, Equatable {

    public enum Status: String, Sendable, Equatable {
        case ok
        case error
    }

    public struct ErrorInfo: Sendable, Equatable {
        public let code: String
        public let message: String

        public init(code: String, message: String) {
            self.code = code
            self.message = message
        }
    }

    public let schemaVersion: Int
    public let status: Status
    public let durationMs: Int
    /// Pretty-printed JSON re-serialized from envelope.data. Nil iff `status == .error`.
    public let dataJSON: String?
    /// Decoded error info. Nil iff `status == .ok`.
    public let error: ErrorInfo?

    public init(
        schemaVersion: Int,
        status: Status,
        durationMs: Int,
        dataJSON: String?,
        error: ErrorInfo?
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.durationMs = durationMs
        self.dataJSON = dataJSON
        self.error = error
    }

    /// The schema version this build of SwiftClaw expects from Pippin's agent envelope.
    /// Bump in lock-step with `AGENT_SCHEMA_VERSION` in pippin's
    /// `pippin/Formatting/AgentOutput.swift`.
    public static let supportedSchemaVersion = 1

    /// Parses an envelope from raw stdout.
    /// Throws ``PippinError`` on malformed input or unsupported schema versions.
    public static func parse(_ stdout: String) throws -> PippinEnvelope {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let bytes = trimmed.data(using: .utf8) else {
            throw PippinError.envelopeMalformed("not UTF-8")
        }
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: bytes, options: [])
        } catch {
            throw PippinError.envelopeMalformed("not valid JSON: \(error.localizedDescription)")
        }
        guard let obj = parsed as? [String: Any] else {
            throw PippinError.envelopeMalformed("envelope root must be a JSON object")
        }

        // Schema version. Reject anything other than the version we know.
        guard let v = obj["v"] as? Int else {
            throw PippinError.envelopeMalformed("missing or non-integer 'v'")
        }
        guard v == supportedSchemaVersion else {
            throw PippinError.unsupportedSchemaVersion(v)
        }

        // Status.
        guard let statusStr = obj["status"] as? String,
              let status = Status(rawValue: statusStr)
        else {
            throw PippinError.envelopeMalformed("missing or unknown 'status' (must be ok|error)")
        }

        // duration_ms — tolerate missing (defensive); pippin always emits it.
        let durationMs = (obj["duration_ms"] as? Int) ?? 0

        switch status {
        case .ok:
            // `data` is required on success; key MUST be present (value may be null).
            guard obj.keys.contains("data") else {
                throw PippinError.envelopeMalformed("status=ok but no 'data' key")
            }
            let payload = obj["data"] ?? NSNull()
            let pretty = try prettyPrint(payload)
            return PippinEnvelope(
                schemaVersion: v,
                status: .ok,
                durationMs: durationMs,
                dataJSON: pretty,
                error: nil
            )

        case .error:
            guard let errObj = obj["error"] as? [String: Any] else {
                throw PippinError.envelopeMalformed("status=error but no 'error' object")
            }
            let code = (errObj["code"] as? String) ?? "unknown"
            let message = (errObj["message"] as? String) ?? "Pippin returned an error with no message."
            return PippinEnvelope(
                schemaVersion: v,
                status: .error,
                durationMs: durationMs,
                dataJSON: nil,
                error: ErrorInfo(code: code, message: message)
            )
        }
    }

    /// Re-serialize the inner payload as pretty-printed JSON. Used for tool output —
    /// keeps the model-facing string roughly comparable to what `--format json`
    /// produced before the v0.20.0 envelope migration.
    private static func prettyPrint(_ payload: Any) throws -> String {
        let bytes: Data
        do {
            bytes = try JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]
            )
        } catch {
            throw PippinError.envelopeMalformed(
                "could not re-serialize 'data' payload: \(error.localizedDescription)"
            )
        }
        return String(data: bytes, encoding: .utf8) ?? "null"
    }
}
