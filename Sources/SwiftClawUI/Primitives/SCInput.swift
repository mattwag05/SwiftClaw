import SwiftUI

/// Labeled text field with optional helper text and validation state.
///
/// Renders a stacked label → field → helper layout using SwiftClaw design
/// tokens. The validation state drives both the border color and the message
/// shown below the field; when `validation` carries a `String`, that message
/// replaces the `helper`. Set `isSecure` to render a `SecureField`.
public struct SCInput: View {
    public enum Validation: Equatable, Sendable {
        case none
        case error(String)
        case warning(String)
        case success(String?)
    }

    private let label: String?
    private let placeholder: String
    private let helper: String?
    private let validation: Validation
    private let isSecure: Bool
    @Binding private var text: String

    @FocusState private var isFocused: Bool

    public init(
        _ label: String? = nil,
        text: Binding<String>,
        placeholder: String = "",
        helper: String? = nil,
        validation: Validation = .none,
        isSecure: Bool = false
    ) {
        self.label = label
        _text = text
        self.placeholder = placeholder
        self.helper = helper
        self.validation = validation
        self.isSecure = isSecure
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let label {
                Text(label)
                    .textStyle(.captionEmph)
                    .foregroundStyle(Theme.foregroundSecondary)
            }

            field
                .textStyle(.body)
                .foregroundStyle(Theme.foregroundPrimary)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(Theme.accent.opacity(isFocused ? 0.35 : 0), lineWidth: 2)
                )

            if let message = messageText {
                Text(message)
                    .textStyle(.caption)
                    .foregroundStyle(messageColor)
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
        } else {
            TextField(placeholder, text: $text)
        }
    }

    private var borderColor: Color {
        switch validation {
        case .none, .success:
            return Theme.border
        case .error:
            return Theme.destructive
        case .warning:
            return Theme.warning
        }
    }

    private var messageText: String? {
        switch validation {
        case .none:
            return helper
        case let .error(msg), let .warning(msg):
            return msg
        case let .success(msg):
            return msg ?? helper
        }
    }

    private var messageColor: Color {
        switch validation {
        case .none, .success:
            return Theme.foregroundSecondary
        case .error:
            return Theme.destructive
        case .warning:
            return Theme.warning
        }
    }
}

#Preview("SCInput — light") {
    @Previewable @State var name = "Matt"
    @Previewable @State var email = "bad-email"
    @Previewable @State var password = "hunter2"
    @Previewable @State var empty = ""

    return VStack(alignment: .leading, spacing: Spacing.lg) {
        SCInput(
            "Display name",
            text: $name,
            placeholder: "Your name",
            helper: "Shown next to your messages."
        )
        SCInput(
            "Email",
            text: $email,
            placeholder: "you@example.com",
            validation: .error("That doesn't look like a valid email.")
        )
        SCInput(
            "Password",
            text: $password,
            placeholder: "••••••",
            validation: .warning("Consider a longer passphrase."),
            isSecure: true
        )
        SCInput(
            "Username",
            text: $empty,
            placeholder: "e.g. claude",
            validation: .success("Available!")
        )
    }
    .padding(Spacing.xl)
    .frame(width: 360)
    .background(Theme.background)
    .preferredColorScheme(.light)
}

#Preview("SCInput — dark") {
    @Previewable @State var name = ""
    @Previewable @State var email = "ok@example.com"

    return VStack(alignment: .leading, spacing: Spacing.lg) {
        SCInput("Display name", text: $name, placeholder: "Your name")
        SCInput(
            "Email",
            text: $email,
            helper: "We'll only use this for sign-in.",
            validation: .success(nil)
        )
    }
    .padding(Spacing.xl)
    .frame(width: 360)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
