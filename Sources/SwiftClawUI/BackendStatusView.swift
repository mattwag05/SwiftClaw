import SwiftUI

public struct BackendStatusView: View {
    public let backendType: BackendType
    public let modelId: String
    public let state: BackendState

    public init(backendType: BackendType, modelId: String, state: BackendState) {
        self.backendType = backendType
        self.modelId = modelId
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 5) {
            statusDot
            Text(displayText.uppercased())
                .font(Theme.monoFont)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
        .accessibilityLabel("Backend: \(displayText)")
    }

    @ViewBuilder
    private var statusDot: some View {
        switch state {
        case .idle:
            Circle()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 6, height: 6)
        case .loading:
            ProgressView().scaleEffect(0.5).frame(width: 10, height: 10)
        case .ready:
            Circle()
                .fill(Theme.brandGold)
                .frame(width: 6, height: 6)
        case .error:
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
        }
    }

    private var displayText: String {
        switch state {
        case .idle: return "Not loaded"
        case .loading(let p): return "Loading \(Int(p * 100))%"
        case .ready:
            let shortModel = modelId.components(separatedBy: "/").last ?? modelId
            return backendType == .mlx ? "On-Device · \(shortModel)" : shortModel
        case .error: return "Error"
        }
    }
}
