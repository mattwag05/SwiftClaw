import SwiftUI

/// Three pulsing dots shown while the model is thinking (before any text arrives).
public struct ThinkingDotsView: View {
    @State private var animating = false

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.secondaryForeground)
                    .frame(width: 6, height: 6)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(Theme.bubblePadding)
        .onAppear { animating = true }
    }
}
