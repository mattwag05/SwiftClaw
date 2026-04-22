import SwiftUI

/// Capsule bar + trailing percentage label showing context-window usage.
///
/// Fill color progresses from `accent` → `warning` (≥ `threshold`) →
/// `destructive` (≥ 0.95). The `.help(...)` tooltip shows the full
/// `used / total tokens (percent%)` breakdown with locale-aware grouping.
public struct SCContextUsageIndicator: View {
    public struct Breakdown: Sendable {
        public var promptTokens: Int
        public var completionTokens: Int
        public var cacheReadTokens: Int?
        public var cacheCreationTokens: Int?

        public init(
            promptTokens: Int,
            completionTokens: Int,
            cacheReadTokens: Int? = nil,
            cacheCreationTokens: Int? = nil
        ) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.cacheReadTokens = cacheReadTokens
            self.cacheCreationTokens = cacheCreationTokens
        }
    }

    private let used: Int
    private let total: Int
    private let isApproximate: Bool
    private let threshold: Double
    private let breakdown: Breakdown?

    public init(
        used: Int,
        total: Int,
        isApproximate: Bool = false,
        threshold: Double = 0.85,
        breakdown: Breakdown? = nil
    ) {
        self.used = used
        self.total = total
        self.isApproximate = isApproximate
        self.threshold = threshold
        self.breakdown = breakdown
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

    private static let groupedFormatter: NumberFormatter = {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.usesGroupingSeparator = true
        return fmt
    }()

    private var tooltip: String {
        func f(_ n: Int) -> String {
            Self.groupedFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
        }
        var lines = ["\(f(used)) / \(f(total)) tokens (\(percentInt)%)"]
        if let b = breakdown {
            lines.append("Prompt: \(f(b.promptTokens))  ·  Completion: \(f(b.completionTokens))")
            // Emit read and write independently — a first-cache-creation request
            // reports read=0 but write>0, and we still want the user to see that
            // cache was written.
            var cacheParts: [String] = []
            if let read = b.cacheReadTokens, read > 0 {
                cacheParts.append("Cache read: \(f(read))")
            }
            if let write = b.cacheCreationTokens, write > 0 {
                cacheParts.append("Cache write: \(f(write))")
            }
            if !cacheParts.isEmpty {
                lines.append(cacheParts.joined(separator: "  ·  "))
            }
        }
        return lines.joined(separator: "\n")
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
