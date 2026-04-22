import SwiftUI

/// Themed modal confirmation dialog. Present inside a `.sheet` or
/// `.fullScreenCover` — `SCAlertDialog` renders the card chrome and keyboard
/// shortcuts but does not present itself.
public struct SCAlertDialog: View {
    public enum Kind: Sendable {
        /// Destructive action — red iconography and red confirm button.
        case delete
        /// Neutral confirmation — accent iconography and accent confirm button.
        case confirm
        /// Warning — amber iconography and amber confirm button.
        case warn
    }

    private let kind: Kind
    private let title: String
    private let message: String?
    private let confirmLabel: String
    private let cancelLabel: String
    private let onConfirm: () -> Void
    private let onCancel: () -> Void

    public init(
        kind: Kind,
        title: String,
        message: String? = nil,
        confirmLabel: String = "Confirm",
        cancelLabel: String = "Cancel",
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.confirmLabel = confirmLabel
        self.cancelLabel = cancelLabel
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28, alignment: .center)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .textStyle(.heading)
                        .foregroundStyle(Theme.foregroundPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let message {
                        Text(message)
                            .textStyle(.body)
                            .foregroundStyle(Theme.foregroundSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack(spacing: Spacing.sm) {
                Spacer(minLength: 0)
                Button(action: onCancel) {
                    Text(cancelLabel)
                        .textStyle(.bodyEmph)
                        .foregroundStyle(Theme.accent)
                        .frame(height: 32)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .stroke(Theme.accent.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button(action: onConfirm) {
                    Text(confirmLabel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(height: 32)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(confirmBackground)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Theme.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private var iconName: String {
        switch kind {
        case .delete: return "trash"
        case .confirm: return "questionmark.circle"
        case .warn: return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch kind {
        case .delete: return Theme.destructive
        case .confirm: return Theme.accent
        case .warn: return Theme.warning
        }
    }

    private var confirmBackground: Color {
        switch kind {
        case .delete: return Theme.destructive
        case .confirm: return Theme.accent
        case .warn: return Theme.warning
        }
    }
}

#Preview("SCAlertDialog — delete, light") {
    SCAlertDialog(
        kind: .delete,
        title: "Delete session?",
        message: "This will permanently remove the session and its messages. This action cannot be undone.",
        confirmLabel: "Delete",
        onConfirm: {},
        onCancel: {}
    )
    .frame(width: 420)
    .padding(Spacing.xl)
    .background(Theme.background)
}

#Preview("SCAlertDialog — warn, dark") {
    SCAlertDialog(
        kind: .warn,
        title: "Unsaved changes",
        message: "You have unsaved edits. Discarding will lose them.",
        confirmLabel: "Discard",
        onConfirm: {},
        onCancel: {}
    )
    .frame(width: 420)
    .padding(Spacing.xl)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}

#Preview("SCAlertDialog — confirm") {
    SCAlertDialog(
        kind: .confirm,
        title: "Load new model?",
        message: "Switching models will unload the current one.",
        confirmLabel: "Load",
        onConfirm: {},
        onCancel: {}
    )
    .frame(width: 420)
    .padding(Spacing.xl)
    .background(Theme.background)
}
