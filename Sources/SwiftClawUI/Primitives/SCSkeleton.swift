import SwiftUI

/// Animated shimmer placeholder block for loading states.
public struct SCSkeleton: View {
    private let width: CGFloat?
    private let height: CGFloat
    private let cornerRadius: CGFloat

    public init(width: CGFloat? = nil, height: CGFloat = 12, cornerRadius: CGFloat = Radius.sm) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        TimelineView(.animation) { context in
            let phase = shimmerPhase(at: context.date)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.gray.opacity(0.08))
                .frame(width: width, height: height)
                .frame(maxWidth: width == nil ? .infinity : nil)
                .overlay(shimmerOverlay(phase: phase))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private func shimmerPhase(at date: Date) -> Double {
        // 1.4 s loop, range -1…1 so the gradient sweeps fully across.
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
        return t * 2.0 - 1.0
    }

    @ViewBuilder
    private func shimmerOverlay(phase: Double) -> some View {
        let gradient = LinearGradient(
            colors: [
                Color.gray.opacity(0.00),
                Color.gray.opacity(0.16),
                Color.gray.opacity(0.00),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        GeometryReader { geo in
            gradient
                .frame(width: geo.size.width * 0.6)
                .offset(x: CGFloat(phase) * geo.size.width)
        }
        .allowsHitTesting(false)
    }
}

#Preview("SCSkeleton — light") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        SCSkeleton(width: 180, height: 14)
        SCSkeleton(height: 12)
        SCSkeleton(height: 12)
        SCSkeleton(width: 240, height: 12)
        HStack(spacing: Spacing.sm) {
            SCSkeleton(width: 40, height: 40, cornerRadius: Radius.md)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SCSkeleton(width: 160, height: 12)
                SCSkeleton(width: 100, height: 10)
            }
        }
    }
    .padding(Spacing.xl)
    .frame(width: 340)
    .background(Theme.surface)
}

#Preview("SCSkeleton — dark") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        SCSkeleton(width: 180, height: 14)
        SCSkeleton(height: 12)
        SCSkeleton(width: 220, height: 12)
    }
    .padding(Spacing.xl)
    .frame(width: 340)
    .background(Theme.surface)
    .preferredColorScheme(.dark)
}
