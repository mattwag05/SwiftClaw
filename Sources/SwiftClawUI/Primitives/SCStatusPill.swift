import SwiftUI

/// Small capsule pill used to communicate status — paired with a tool name or
/// action label. Atomic building block used directly by callers and internally
/// by `SCStatusCard`.
public struct SCStatusPill: View {
    public enum Status: Sendable, Hashable {
        case running, pending, done, error, denied

        fileprivate var label: String {
            switch self {
            case .running: return "RUNNING"
            case .pending: return "PENDING"
            case .done: return "DONE"
            case .error: return "ERROR"
            case .denied: return "DENIED"
            }
        }

        fileprivate var iconSystemName: String {
            switch self {
            case .running: return "arrow.trianglehead.2.clockwise"
            case .pending: return "exclamationmark"
            case .done: return "checkmark"
            case .error: return "xmark"
            case .denied: return "xmark.shield"
            }
        }

        fileprivate var background: Color {
            switch self {
            case .running: return Theme.Pill.running
            case .pending: return Theme.Pill.pending
            case .done: return Theme.Pill.done
            case .error: return Theme.Pill.error
            case .denied: return Theme.Pill.denied
            }
        }

        fileprivate var foreground: Color {
            switch self {
            case .running: return Theme.Pill.runningFG
            case .pending: return Theme.Pill.pendingFG
            case .done: return Theme.Pill.doneFG
            case .error: return Theme.Pill.errorFG
            case .denied: return Theme.Pill.deniedFG
            }
        }
    }

    private let status: Status
    private let label: String?

    public init(_ status: Status, label: String? = nil) {
        self.status = status
        self.label = label
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: status.iconSystemName)
                .font(.system(size: 10, weight: .semibold))
            Text(label ?? status.label)
                .textStyle(.monoLabel)
        }
        .foregroundStyle(status.foreground)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(status.background, in: Capsule())
    }
}

#Preview("SCStatusPill — light") {
    HStack(spacing: Spacing.sm) {
        SCStatusPill(.running)
        SCStatusPill(.pending, label: "NEEDS APPROVAL")
        SCStatusPill(.done)
        SCStatusPill(.error)
        SCStatusPill(.denied)
    }
    .padding(Spacing.xl)
    .background(Theme.surface)
    .preferredColorScheme(.light)
}

#Preview("SCStatusPill — dark") {
    HStack(spacing: Spacing.sm) {
        SCStatusPill(.running)
        SCStatusPill(.pending, label: "NEEDS APPROVAL")
        SCStatusPill(.done)
        SCStatusPill(.error)
        SCStatusPill(.denied)
    }
    .padding(Spacing.xl)
    .background(Theme.surface)
    .preferredColorScheme(.dark)
}
