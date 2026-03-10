import SwiftUI
import SwiftClawCore

public struct SessionRowView: View {
    public let summary: SessionSummary

    public init(summary: SessionSummary) { self.summary = summary }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(
                summary.preview.isEmpty ? "New chat" : summary.preview,
                systemImage: "bubble.left.and.bubble.right"
            )
            .lineLimit(1)
            .font(Theme.bodyFont)
            Text(summary.updatedAt, style: .relative)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondaryForeground)
        }
        .padding(.vertical, 2)
        .accessibilityLabel(summary.preview.isEmpty ? "New chat" : summary.preview)
    }
}
