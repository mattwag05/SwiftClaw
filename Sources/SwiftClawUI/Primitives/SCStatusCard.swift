import SwiftUI

/// Row-style status card used for tool-call and agent-action surfaces.
///
/// Renders a single horizontal row with an optional leading SF Symbol, a
/// mono-cased title, and a trailing pill that reflects `Status`. An optional
/// subtitle sits below the row in a muted caption style.
public struct SCStatusCard: View {
    public typealias Status = SCStatusPill.Status

    private let title: String
    private let status: Status
    private let iconSystemName: String?
    private let subtitle: String?

    public init(
        title: String,
        status: Status,
        iconSystemName: String? = nil,
        subtitle: String? = nil
    ) {
        self.title = title
        self.status = status
        self.iconSystemName = iconSystemName
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                if let iconSystemName {
                    Image(systemName: iconSystemName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.foregroundSecondary)
                }

                Text(title)
                    .textStyle(.monoLabel)
                    .foregroundStyle(Theme.foregroundPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: Spacing.sm)

                SCStatusPill(status)
            }

            if let subtitle {
                Text(subtitle)
                    .textStyle(.caption)
                    .foregroundStyle(Theme.foregroundSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }
}

#Preview("Default") {
    VStack(spacing: Spacing.md) {
        SCStatusCard(
            title: "read_file",
            status: .running,
            iconSystemName: "doc.text",
            subtitle: "Sources/SwiftClawUI/Theme.swift"
        )
        SCStatusCard(
            title: "write_file",
            status: .pending,
            iconSystemName: "square.and.pencil"
        )
        SCStatusCard(
            title: "run_tests",
            status: .done,
            iconSystemName: "checkmark.seal",
            subtitle: "112 passed in 3.8s"
        )
        SCStatusCard(
            title: "deploy",
            status: .error,
            iconSystemName: "bolt.horizontal",
            subtitle: "Exit code 2"
        )
        SCStatusCard(
            title: "shell_exec",
            status: .denied,
            iconSystemName: "terminal"
        )
    }
    .padding(Spacing.xl)
    .frame(width: 420)
    .background(Theme.background)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: Spacing.md) {
        SCStatusCard(
            title: "read_file",
            status: .running,
            iconSystemName: "doc.text",
            subtitle: "Sources/SwiftClawUI/Theme.swift"
        )
        SCStatusCard(
            title: "write_file",
            status: .pending,
            iconSystemName: "square.and.pencil"
        )
        SCStatusCard(
            title: "run_tests",
            status: .done,
            iconSystemName: "checkmark.seal",
            subtitle: "112 passed in 3.8s"
        )
        SCStatusCard(
            title: "deploy",
            status: .error,
            iconSystemName: "bolt.horizontal",
            subtitle: "Exit code 2"
        )
        SCStatusCard(
            title: "shell_exec",
            status: .denied,
            iconSystemName: "terminal"
        )
    }
    .padding(Spacing.xl)
    .frame(width: 420)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
