import SwiftUI

// MARK: - Animation constants

public extension Animation {
    /// The signature Gemma Chat easing: snappy deceleration.
    /// Maps to CSS cubic-bezier(0.16, 1, 0.3, 1) at 0.35s.
    static let gemmaSnap = Animation.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.35)

    /// Shorter variant for quick micro-interactions (0.25s).
    static let gemmaQuick = Animation.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.25)

    /// Slower variant for large pane transitions (0.4s).
    static let gemmaSlow = Animation.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.40)

    /// Shimmer gradient sweep: 1.8s linear, looping.
    static let shimmerSweep = Animation.linear(duration: 1.8).repeatForever(autoreverses: false)

    /// Shimmer text sweep: 2.2s linear, looping.
    static let shimmerText = Animation.linear(duration: 2.2).repeatForever(autoreverses: false)

    /// Dot-pulse loader: 1.2s ease-in-out, looping.
    static let dotPulse = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
}

// MARK: - Stagger helpers

public enum GemmaStagger {
    /// Delay for the nth item in a staggered entry sequence.
    /// Increment is 40ms per item, capped at 150ms.
    public static func delay(for index: Int, increment: Double = 0.04, cap: Double = 0.15) -> Double {
        min(Double(index) * increment, cap)
    }
}

// MARK: - Shimmer modifier

/// A repeating gradient-sweep shimmer over any view.
/// Use `.shimmering()` on text labels.
public struct ShimmerModifier: ViewModifier {
    let duration: Double
    @State private var phase: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.6), location: 0.4),
                            .init(color: .white.opacity(0.8), location: 0.5),
                            .init(color: .white.opacity(0.6), location: 0.6),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: UnitPoint(x: phase - 0.5, y: 0),
                        endPoint:   UnitPoint(x: phase + 0.5, y: 0)
                    )
                    .blendMode(.sourceAtop)
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width)
                    .onAppear {
                        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                            phase = 2
                        }
                    }
                }
            )
            .clipped()
    }
}

public extension View {
    func shimmering(duration: Double = 2.2) -> some View {
        modifier(ShimmerModifier(duration: duration))
    }
}

// MARK: - Streaming caret

/// Blinking `▍` caret that appears while a bubble is actively streaming.
public struct StreamingCaret: View {
    @State private var visible = true

    public init() {}

    public var body: some View {
        Text("▍")
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

// MARK: - Message entry transition

/// The entry transition applied to each new message bubble.
public extension AnyTransition {
    static var gemmaMessageEntry: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 4)),
            removal: .opacity
        )
    }
}
