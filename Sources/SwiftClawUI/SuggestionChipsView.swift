import SwiftUI

/// Horizontally wrapping suggestion chips that hint at agent capabilities.
public struct SuggestionChipsView: View {
    public let suggestions: [String]
    public let onSelect: (String) -> Void

    public init(suggestions: [String], onSelect: @escaping (String) -> Void) {
        self.suggestions = suggestions
        self.onSelect = onSelect
    }

    public var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 120, maximum: 200))],
            spacing: 8
        ) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    Text(suggestion)
                        .font(.system(.caption, design: .rounded))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(Theme.brandBlue.opacity(0.08), in: Capsule())
                        .foregroundStyle(Theme.brandDeepBlue)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
