import SwiftUI

public struct EmptyStateView: View {
    public let onNewChat: () -> Void

    public init(onNewChat: @escaping () -> Void) { self.onNewChat = onNewChat }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bird")
                .font(.system(size: 52))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.brandBlue)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("START A CONVERSATION")
                    .font(Theme.monoLabelFont)
                    .foregroundStyle(Theme.primaryForeground)
                Text("Ask anything — SwiftClaw has tools for system info,\nfiles, shell commands, and more.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }

            Button("New Chat") {
                onNewChat()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel("Start a new chat")
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
