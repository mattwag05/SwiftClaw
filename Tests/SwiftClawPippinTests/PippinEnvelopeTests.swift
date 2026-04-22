import Foundation
import Testing
@testable import SwiftClawPippin

/// Tests for PippinEnvelope parsing. Pippin v0.20.0 wraps every
/// `--format agent` response in {"v":1,"status":...,"duration_ms":N,"data":?,"error":?}.
@Suite("PippinEnvelope parsing")
struct PippinEnvelopeTests {

    // MARK: - Successful envelopes

    @Test("parse: ok with array payload")
    func okArrayPayload() throws {
        let raw = #"{"v":1,"status":"ok","duration_ms":42,"data":[{"name":"iCloud","email":"a@b.c"}]}"#
        let env = try PippinEnvelope.parse(raw)
        #expect(env.schemaVersion == 1)
        #expect(env.status == .ok)
        #expect(env.durationMs == 42)
        #expect(env.error == nil)
        let data = try #require(env.dataJSON)
        // Re-parse the pretty JSON to verify structural equivalence (don't assume formatting).
        let arr = try #require(
            try JSONSerialization.jsonObject(with: Data(data.utf8)) as? [[String: String]]
        )
        #expect(arr.count == 1)
        #expect(arr[0]["name"] == "iCloud")
        #expect(arr[0]["email"] == "a@b.c")
    }

    @Test("parse: ok with object payload")
    func okObjectPayload() throws {
        let raw = #"{"v":1,"status":"ok","duration_ms":7,"data":{"id":"abc","subject":"hi"}}"#
        let env = try PippinEnvelope.parse(raw)
        #expect(env.status == .ok)
        let data = try #require(env.dataJSON)
        let obj = try #require(
            try JSONSerialization.jsonObject(with: Data(data.utf8)) as? [String: String]
        )
        #expect(obj["id"] == "abc")
        #expect(obj["subject"] == "hi")
    }

    @Test("parse: ok with null payload survives")
    func okNullPayload() throws {
        let raw = #"{"v":1,"status":"ok","duration_ms":3,"data":null}"#
        let env = try PippinEnvelope.parse(raw)
        #expect(env.status == .ok)
        let data = try #require(env.dataJSON)
        #expect(data == "null")
    }

    @Test("parse: tolerates re-ordered keys")
    func reorderedKeys() throws {
        // Real Pippin output sometimes orders keys as {data,status,duration_ms,v}.
        let raw = #"{"data":[1,2,3],"status":"ok","duration_ms":1,"v":1}"#
        let env = try PippinEnvelope.parse(raw)
        #expect(env.status == .ok)
        #expect(env.schemaVersion == 1)
        let data = try #require(env.dataJSON)
        let arr = try #require(try JSONSerialization.jsonObject(with: Data(data.utf8)) as? [Int])
        #expect(arr == [1, 2, 3])
    }

    @Test("parse: tolerates trailing whitespace and newlines")
    func trailingWhitespace() throws {
        let raw = "  {\"v\":1,\"status\":\"ok\",\"duration_ms\":0,\"data\":[]}\n\n"
        let env = try PippinEnvelope.parse(raw)
        #expect(env.status == .ok)
    }

    // MARK: - Error envelopes

    @Test("parse: error envelope surfaces code + message")
    func errorEnvelope() throws {
        let raw =
            #"{"v":1,"status":"error","duration_ms":0,"error":{"code":"invalid_message_id","message":"Invalid message id: x"}}"#
        let env = try PippinEnvelope.parse(raw)
        #expect(env.status == .error)
        #expect(env.dataJSON == nil)
        let err = try #require(env.error)
        #expect(err.code == "invalid_message_id")
        #expect(err.message == "Invalid message id: x")
    }

    @Test("parse: error envelope with missing fields uses safe defaults")
    func errorEnvelopeMissingFields() throws {
        // Defensive: Pippin should always include code+message, but tolerate absence.
        let raw = #"{"v":1,"status":"error","duration_ms":0,"error":{}}"#
        let env = try PippinEnvelope.parse(raw)
        let err = try #require(env.error)
        #expect(err.code == "unknown")
        #expect(!err.message.isEmpty)
    }

    // MARK: - Failure modes

    @Test("parse: rejects non-JSON input")
    func rejectsNonJSON() {
        #expect(throws: PippinError.self) {
            _ = try PippinEnvelope.parse("not json")
        }
    }

    @Test("parse: rejects missing v")
    func rejectsMissingVersion() {
        let raw = #"{"status":"ok","duration_ms":0,"data":[]}"#
        #expect(throws: PippinError.self) {
            _ = try PippinEnvelope.parse(raw)
        }
    }

    @Test("parse: rejects unsupported schema version")
    func rejectsUnsupportedVersion() {
        let raw = #"{"v":2,"status":"ok","duration_ms":0,"data":[]}"#
        do {
            _ = try PippinEnvelope.parse(raw)
            Issue.record("expected unsupportedSchemaVersion")
        } catch let PippinError.unsupportedSchemaVersion(v) {
            #expect(v == 2)
        } catch {
            Issue.record("expected unsupportedSchemaVersion, got \(error)")
        }
    }

    @Test("parse: rejects ok-status with no data field")
    func rejectsOkWithoutData() {
        let raw = #"{"v":1,"status":"ok","duration_ms":0}"#
        #expect(throws: PippinError.self) {
            _ = try PippinEnvelope.parse(raw)
        }
    }

    @Test("parse: rejects error-status with no error object")
    func rejectsErrorWithoutErrorObj() {
        let raw = #"{"v":1,"status":"error","duration_ms":0}"#
        #expect(throws: PippinError.self) {
            _ = try PippinEnvelope.parse(raw)
        }
    }

    @Test("parse: rejects unknown status string")
    func rejectsUnknownStatus() {
        let raw = #"{"v":1,"status":"weird","duration_ms":0,"data":[]}"#
        #expect(throws: PippinError.self) {
            _ = try PippinEnvelope.parse(raw)
        }
    }
}
