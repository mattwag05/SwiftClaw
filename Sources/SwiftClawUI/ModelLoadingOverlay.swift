import SwiftUI
import AppKit

public struct ModelLoadingOverlay: View {
    public let progress: Double

    public init(progress: Double) { self.progress = progress }

    public var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).opacity(0.85)
            VStack(spacing: 16) {
                ProgressView(value: progress > 0 ? progress : nil)
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                if progress > 0 {
                    Text("Loading model… \(Int(progress * 100))%")
                        .font(.headline)
                } else {
                    Text("Loading model…")
                        .font(.headline)
                }
            }
            .padding(40)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .ignoresSafeArea()
        .accessibilityLabel("Loading model, \(progress > 0 ? "\(Int(progress * 100))%" : "please wait")")
    }
}
