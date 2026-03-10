import SwiftUI

public struct ToolCallBubbleView: View {
    public let name: String

    public init(name: String) { self.name = name }

    public var body: some View {
        HStack {
            Image(systemName: "wrench.and.screwdriver")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.secondaryForeground)
            Text("Calling \(name)…")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.secondaryForeground)
            ProgressView().scaleEffect(0.6)
        }
        .padding(.leading, 4)
    }
}

public struct ToolResultBubbleView: View {
    public let content: String
    public let isError: Bool

    public init(content: String, isError: Bool) {
        self.content = content
        self.isError = isError
    }

    public var body: some View {
        DisclosureGroup {
            Text(content)
                .font(Theme.monoFont)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
        } label: {
            HStack {
                Image(systemName: isError ? "xmark.circle" : "checkmark.circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isError ? Theme.errorColor : Theme.successColor)
                Text(isError ? "Tool error" : "Tool result")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.secondaryForeground)
            }
        }
        .padding(.leading, 4)
    }
}

public struct WarningBubbleView: View {
    public let message: String

    public init(message: String) { self.message = message }

    public var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.warningColor)
            Text(message)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.warningColor)
        }
        .padding(.leading, 4)
    }
}
