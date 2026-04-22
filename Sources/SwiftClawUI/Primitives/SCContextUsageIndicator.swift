import SwiftUI

/// Capsule bar + trailing percentage label showing context-window usage.
///
/// Fill color progresses from `accent` → `warning` (≥ `threshold`) →
/// `destructive` (≥ 0.95). The `.help(...)` tooltip shows the full
/// `used / total tokens (percent%)` breakdown with locale-aware grouping.
public struct SCContextUsageIndicator: View {
    private let used: Int
    private let total: Int
    private let isApproximate: Bool
    private let threshold: Double

    public init(
        used: Int,
        total: Int,
        isApproximate: Bool = false,
        threshold: Double = 0.85
    ) {
        self.used = used
        self.total = total
        self.isApproximate = isApproximate
        self.threshold = threshold
    }

    private var percent: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(used) / Double(total), 0), 1)
    }

    private var fillColor: Color {
        if percent >= 0.95 { return Theme.destructive }
        if percent >= threshold { return Theme.warning }
        return Theme.accent
    }

    private var percentInt: Int {
        Int((percent * 100).rounded(.down))
    }

    private var percentLabel: String {
        let prefix = isApproximate ? "~" : ""
        return "\(prefix)\(percentInt)%"
    }

    private var tooltip: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.usesGroupingSeparator = true
        let usedStr = fmt.string(from: NSNumber(value: used)) ?? "\(used)"
        let totalStr = fmt.string(from: NSNumber(value: total)) ?? "\(total)"
        return "\(usedStr) / \(totalStr) tokens (\(percentInt)%)"
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.borderSubtle)
                    .frame(width: 90, height: 4)

                Capsule()
                    .fill(fillColor)
                    .frame(width: 90 * percent, height: 4)
            }
            .frame(width: 90, height: 4)

            Text(percentLabel)
                .textStyle(.captionEmph)
                .foregroundStyle(Theme.foregroundSecondary)
                .monospacedDigit()
        }
        .help(tooltip)
    }
}

#Preview("SCContextUsageIndicator — light") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        SCContextUsageIndicator(used: 4200, total: 32768)
        SCContextUsageIndicator(used: 12453, total: 32768)
        SCContextUsageIndicator(used: 12453, total: 32768, isApproximate: true)
        SCContextUsageIndicator(used: 28500, total: 32768)
        SCContextUsageIndicator(used: 31500, total: 32768)
        SCContextUsageIndicator(used: 32000, total: 32768)
    }
    .padding(Spacing.xl)
    .background(Theme.background)
}

#Preview("SCContextUsageIndicator — dark") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        SCContextUsageIndicator(used: 2000, total: 128_000)
        SCContextUsageIndicator(used: 110_000, total: 128_000, isApproximate: true)
        SCContextUsageIndicator(used: 125_000, total: 128_000)
    }
    .padding(Spacing.xl)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
