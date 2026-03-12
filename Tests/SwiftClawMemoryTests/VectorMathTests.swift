import Testing
import Foundation
@testable import SwiftClawMemory

@Suite("VectorMath Tests")
struct VectorMathTests {

    @Test func cosineSimilarityIdenticalVectors() {
        let v: [Float] = [1.0, 0.0, 0.5, -0.3]
        let result = cosineSimilarity(v, v)
        #expect(abs(result - 1.0) < 1e-5, "Identical vectors should have similarity ~1.0, got \(result)")
    }

    @Test func cosineSimilarityOrthogonalVectors() {
        let a: [Float] = [1.0, 0.0, 0.0]
        let b: [Float] = [0.0, 1.0, 0.0]
        let result = cosineSimilarity(a, b)
        #expect(abs(result) < 1e-5, "Orthogonal vectors should have similarity ~0.0, got \(result)")
    }

    @Test func cosineSimilarityZeroVector() {
        let zero: [Float] = [0.0, 0.0, 0.0]
        let nonzero: [Float] = [1.0, 2.0, 3.0]
        let result = cosineSimilarity(zero, nonzero)
        #expect(result == 0.0, "Zero vector should yield similarity 0.0, got \(result)")
    }

    @Test func cosineSimilarityOppositeVectors() {
        // Opposite directions should give -1.0
        let a: [Float] = [1.0, 0.0, 0.0]
        let b: [Float] = [-1.0, 0.0, 0.0]
        let result = cosineSimilarity(a, b)
        #expect(abs(result - (-1.0)) < 1e-5, "Opposite vectors should have similarity ~-1.0, got \(result)")
    }

    @Test func cosineSimilarityMismatchedLengthsReturnsZero() {
        let a: [Float] = [1.0, 2.0]
        let b: [Float] = [1.0, 2.0, 3.0]
        let result = cosineSimilarity(a, b)
        #expect(result == 0.0, "Mismatched lengths should return 0.0, got \(result)")
    }

    @Test func cosineSimilarityEmptyVectorsReturnZero() {
        let result = cosineSimilarity([], [])
        #expect(result == 0.0, "Empty vectors should return 0.0, got \(result)")
    }
}
