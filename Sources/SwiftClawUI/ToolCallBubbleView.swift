import SwiftUI

// MARK: - Tool running

public struct ToolCallBubbleView: View {
    public let name: String

    public init(name: String) {
        self.name = name
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(name)
                .font(Theme.monoLabelFont)
                .foregroundStyle(Theme.secondaryForeground)
            SCStatusPill(.running)
        }
        .padding(.leading, 2)
    }
}

// MARK: - Tool result

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
                .padding(.top, 6)
                .padding(.horizontal, 2)
        } label: {
            HStack(spacing: Spacing.sm) {
                Text("result")
                    .font(Theme.monoLabelFont)
                    .foregroundStyle(Theme.secondaryForeground)
                SCStatusPill(isError ? .error : .done)
            }
        }
        .padding(.leading, 2)
    }
}

// MARK: - Tool pending approval

public struct ToolCallPendingView: View {
    public let name: String
    public let arguments: String
    public let onApprove: () -> Void
    public let onDeny: () -> Void

    public init(name: String, arguments: String, onApprove: @escaping () -> Void, onDeny: @escaping () -> Void) {
        self.name = name
        self.arguments = arguments
        self.onApprove = onApprove
        self.onDeny = onDeny
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: Spacing.sm) {
                Text(name)
                    .font(Theme.monoLabelFont)
                    .foregroundStyle(Theme.primaryForeground)
                SCStatusPill(.pending, label: "NEEDS APPROVAL")
            }
            DisclosureGroup {
                Text(arguments)
                    .font(Theme.monoFont)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            } label: {
                Text("ARGUMENTS")
                    .font(Theme.monoFont)
                    .foregroundStyle(Theme.secondaryForeground)
            }
            HStack(spacing: 10) {
                Button("Deny", role: .destructive) { onDeny() }
                    .keyboardShortcut(.escape)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Approve") { onApprove() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(Theme.pillPending, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.pillPendingFG.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Tool denied

public struct ToolCallDeniedView: View {
    public let name: String

    public init(name: String) {
        self.name = name
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(name)
                .font(Theme.monoLabelFont)
                .foregroundStyle(Theme.secondaryForeground)
            SCStatusPill(.denied)
        }
        .padding(.leading, 2)
    }
}

// MARK: - Warning

public struct WarningBubbleView: View {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.warningColor)
                .font(.caption)
                .accessibilityHidden(true)
            Text(message)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.warningColor)
        }
        .padding(.leading, 2)
    }
}
