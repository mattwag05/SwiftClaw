import SwiftUI
import SwiftClawCore

/// Mode-aware empty state shown when no messages exist in a session.
public struct GemmaEmptyState: View {
    public let mode: SessionMode
    public let onSelectSuggestion: (String) -> Void

    public init(mode: SessionMode, onSelectSuggestion: @escaping (String) -> Void) {
        self.mode = mode
        self.onSelectSuggestion = onSelectSuggestion
    }

    private var icon: String { mode == .build ? "hammer" : "bird" }
    private var headline: String { mode == .build ? "WHAT SHALL WE BUILD?" : "WHAT CAN I HELP WITH?" }
    private var suggestions: [String] {
        mode == .build
            ? ["Build a hello world web page", "Create a React component", "Write a Python script", "Make a simple game"]
            : ["What's my system info?", "Show disk usage", "List running processes", "What time is it?"]
    }

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(GemmaForeground.tertiary)
            Text(headline)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(GemmaForeground.tertiary)
                .tracking(1.5)
            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onSelectSuggestion(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.callout)
                            .foregroundStyle(GemmaForeground.secondary)
                            .frame(maxWidth: 360, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Surface.s04)
                            .clipShape(RoundedRectangle(cornerRadius: GemmaRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: GemmaRadius.md)
                                    .strokeBorder(GemmaBorder.subtle, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.gemmaSnap, value: mode)
    }
}
