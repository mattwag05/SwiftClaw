import Accelerate

/// Cosine similarity between two equal-length Float vectors using vDSP.
///
/// Returns a value in [-1, 1], or 0 if either vector has zero norm or the
/// lengths differ.
public func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    guard a.count == b.count, !a.isEmpty else { return 0 }

    var dot: Float = 0
    var normASq: Float = 0
    var normBSq: Float = 0

    vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
    vDSP_svesq(a, 1, &normASq, vDSP_Length(a.count))
    vDSP_svesq(b, 1, &normBSq, vDSP_Length(b.count))

    guard normASq > 0, normBSq > 0 else { return 0 }
    return dot / (normASq.squareRoot() * normBSq.squareRoot())
}
