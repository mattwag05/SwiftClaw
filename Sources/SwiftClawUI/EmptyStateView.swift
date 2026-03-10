import SwiftUI

public struct EmptyStateView: View {
    public let onNewChat: () -> Void

    public init(onNewChat: @escaping () -> Void) { self.onNewChat = onNewChat }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text("Start a Conversation")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Ask anything — SwiftClaw has tools for system info, files, shell commands, and more.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
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
