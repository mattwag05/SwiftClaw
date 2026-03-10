import SwiftUI

public struct ErrorBannerView: View {
    public let message: String
    public let onRetry: () -> Void

    public init(message: String, onRetry: @escaping () -> Void) {
        self.message = message
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.errorColor)
                Text(message)
                    .foregroundStyle(Theme.errorColor)
                    .lineLimit(2)
                Spacer()
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.errorColor)
                    .accessibilityLabel("Retry loading backend")
            }
            .padding()
            .background(.regularMaterial)
            Spacer()
        }
    }
}
