import Testing
import Foundation
@testable import SwiftClawMLX

@Suite("EvalResult")
struct EvalResultTests {

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let original = EvalResult(
            timestamp: date,
            modelId: "test-model",
            adapterA: nil,
            adapterB: "my-adapter",
            prompt: "What is 2+2?",
            responseA: "4",
            responseB: "Four",
            winner: .b
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(EvalResult.self, from: data)

        #expect(decoded.modelId == original.modelId)
        #expect(decoded.adapterA == nil)
        #expect(decoded.adapterB == original.adapterB)
        #expect(decoded.prompt == original.prompt)
        #expect(decoded.responseA == original.responseA)
        #expect(decoded.responseB == original.responseB)
        #expect(decoded.winner == .b)
        #expect(abs(decoded.timestamp.timeIntervalSince1970 - date.timeIntervalSince1970) < 1)
    }

    @Test("Winner skip encodes and decodes correctly")
    func winnerSkip() throws {
        let result = EvalResult(
            modelId: "m", adapterA: nil, adapterB: "b",
            prompt: "p", responseA: "a", responseB: "b", winner: .skip
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(EvalResult.self, from: data)
        #expect(decoded.winner == .skip)
    }

    @Test("nil winner encodes and decodes as nil")
    func nilWinner() throws {
        let result = EvalResult(
            modelId: "m", adapterA: nil, adapterB: "b",
            prompt: "p", responseA: "a", responseB: "b", winner: nil
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(EvalResult.self, from: data)
        #expect(decoded.winner == nil)
    }
}
