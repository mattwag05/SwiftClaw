import SwiftUI
import SwiftClawCore

public struct SessionRowView: View {
    public let summary: SessionSummary

    public init(summary: SessionSummary) { self.summary = summary }

    public var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.preview.isEmpty ? "New chat" : summary.preview)
                    .lineLimit(1)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.primaryForeground)
                Text(summary.updatedAt, style: .relative)
                    .font(Theme.monoFont)
                    .foregroundStyle(Theme.secondaryForeground)
            }
        }
        .padding(.vertical, 3)
        .accessibilityLabel(summary.preview.isEmpty ? "New chat" : summary.preview)
    }
}
