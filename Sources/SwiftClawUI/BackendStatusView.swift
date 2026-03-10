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
        HStack(spacing: 4) {
            statusIcon
            Text(displayText)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .accessibilityLabel("Backend: \(displayText)")
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .idle:
            Image(systemName: "circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .font(.caption)
        case .loading:
            ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
        case .ready:
            Image(systemName: backendType == .mlx ? "cpu.fill" : "network")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.green)
                .font(.caption)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.red)
                .font(.caption)
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
