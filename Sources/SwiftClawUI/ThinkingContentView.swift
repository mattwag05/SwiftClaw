import SwiftUI

/// Collapsible view showing the model's reasoning/thinking content.
public struct ThinkingContentView: View {
    public let text: String
    @State private var isExpanded = false

    public init(text: String) { self.text = text }

    public var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(text)
                .font(Theme.monoFont)
                .foregroundStyle(Theme.secondaryForeground)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "brain")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.secondaryForeground)
                Text("Thinking")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.secondaryForeground)
            }
        }
        .padding(.leading, 4)
    }
}
