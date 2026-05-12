import SwiftUI

/// Activity bar shown under an actively-streaming assistant bubble.
/// Rotates through mode-specific verbs every 4s, shows char count and elapsed time.
public struct GemmaActivityBar: View {
    public let charCount: Int
    public let isBuildMode: Bool

    public init(charCount: Int, isBuildMode: Bool = false) {
        self.charCount = charCount
        self.isBuildMode = isBuildMode
    }

    private static let chatVerbs = ["Thinking", "Considering", "Planning", "Pondering", "Reasoning", "Sketching"]
    private static let buildVerbs = ["Writing", "Composing", "Drafting", "Building"]

    @State private var verbIndex = 0
    @State private var elapsed: Int = 0
    @State private var tickCount: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var verbs: [String] { isBuildMode ? Self.buildVerbs : Self.chatVerbs }

    public var body: some View {
        HStack(spacing: 6) {
            Text(verbs[verbIndex % verbs.count])
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(GemmaForeground.secondary)
                .animation(.gemmaQuick, value: verbIndex)
            Text("·")
                .foregroundStyle(GemmaForeground.tertiary)
            Text("\(charCount) chars")
                .font(.system(.caption2, design: .monospaced).monospacedDigit())
                .foregroundStyle(GemmaForeground.tertiary)
            Text("·")
                .foregroundStyle(GemmaForeground.tertiary)
            Text(elapsedString)
                .font(.system(.caption2, design: .monospaced).monospacedDigit())
                .foregroundStyle(GemmaForeground.tertiary)
        }
        .onReceive(timer) { _ in
            elapsed += 1
            tickCount += 1
            if tickCount % 4 == 0 { verbIndex += 1 }
        }
    }

    private var elapsedString: String {
        elapsed < 60 ? "\(elapsed)s" : "\(elapsed / 60)m\(elapsed % 60)s"
    }
}
