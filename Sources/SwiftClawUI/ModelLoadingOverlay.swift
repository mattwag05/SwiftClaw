import SwiftUI
import AppKit

public struct ModelLoadingOverlay: View {
    public let progress: Double

    public init(progress: Double) { self.progress = progress }

    public var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).opacity(0.85)
            VStack(spacing: 16) {
                if progress > 0 {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                    Text("Loading model… \(Int(progress * 100))%")
                        .font(.headline)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
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
