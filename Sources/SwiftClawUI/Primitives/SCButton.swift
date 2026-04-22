import SwiftUI

/// Themed button primitive backing the SwiftClaw design system.
public struct SCButton: View {
    public enum Variant: Sendable {
        case primary
        case secondary
        case ghost
        case destructive
        case icon(String)
    }

    public enum Size: Sendable {
        case small, medium, large

        var height: CGFloat {
            switch self {
            case .small: return 24
            case .medium: return 32
            case .large: return 40
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 14
            case .large: return 18
            }
        }

        var iconFontSize: CGFloat {
            switch self {
            case .small: return 11
            case .medium: return 14
            case .large: return 17
            }
        }

        var textStyle: TextStyle {
            switch self {
            case .small: return .captionEmph
            case .medium, .large: return .bodyEmph
            }
        }
    }

    private let title: String
    private let variant: Variant
    private let size: Size
    private let action: () -> Void
    private let accessibilityLabelOverride: String?

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    public init(
        _ title: String = "",
        variant: Variant = .primary,
        size: Size = .medium,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        // Icon-only buttons fall back to reading the raw SF Symbol name in
        // VoiceOver without a label, so require a non-empty accessibilityLabel
        // at call site — guards callers that reach `.icon` directly, not just
        // the `init(icon:label:size:action:)` overload.
        if case .icon = variant {
            let trimmed = accessibilityLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            precondition(
                !trimmed.isEmpty,
                "SCButton icon-only buttons require a non-empty accessibilityLabel. Use init(icon:label:size:action:) or provide accessibilityLabel when variant is .icon."
            )
        }
        self.title = title
        self.variant = variant
        self.size = size
        self.action = action
        accessibilityLabelOverride = accessibilityLabel
    }

    /// Icon-only button. `label` is the VoiceOver/accessibility label and is **required**
    /// — icon-only buttons otherwise fall back to the raw SF Symbol name, which is
    /// noise for assistive tech users. The same string is also surfaced as a hover
    /// tooltip via `.help(label)` so pointer users get a matching hint.
    public init(
        icon systemName: String,
        label: String,
        size: Size = .medium,
        action: @escaping () -> Void
    ) {
        self.init(
            "",
            variant: .icon(systemName),
            size: size,
            accessibilityLabel: label,
            action: action
        )
    }

    public var body: some View {
        let button = Button(action: action) {
            label
                .frame(height: size.height)
                .frame(minWidth: iconOnly ? size.height : nil)
                .padding(.horizontal, iconOnly ? 0 : size.horizontalPadding)
                .background(background)
                .overlay(border)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .foregroundStyle(foreground)
                .opacity(isEnabled ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering && isEnabled
            }
        }

        if let axLabel = accessibilityLabelOverride {
            button
                .accessibilityLabel(axLabel)
                .help(axLabel)
        } else {
            button
        }
    }

    @ViewBuilder
    private var label: some View {
        switch variant {
        case let .icon(name):
            Image(systemName: name)
                .font(.system(size: size.iconFontSize, weight: .medium))
        default:
            Text(title).textStyle(size.textStyle)
        }
    }

    private var iconOnly: Bool {
        if case .icon = variant { return true }
        return false
    }

    private var background: Color {
        switch variant {
        case .primary:
            return isHovered ? Theme.accentDeep : Theme.accent
        case .destructive:
            return isHovered ? Theme.destructive.opacity(0.85) : Theme.destructive
        case .secondary:
            return isHovered ? Theme.accent.opacity(0.08) : .clear
        case .ghost, .icon:
            return isHovered ? Theme.accent.opacity(0.10) : .clear
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary, .destructive:
            return .white
        case .secondary, .ghost, .icon:
            return Theme.accent
        }
    }

    @ViewBuilder
    private var border: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        switch variant {
        case .secondary:
            shape.stroke(Theme.accent.opacity(isHovered ? 0.8 : 0.5), lineWidth: 1)
        default:
            shape.stroke(Color.clear, lineWidth: 0)
        }
    }
}

#Preview("SCButton — light") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        HStack(spacing: Spacing.sm) {
            SCButton("Primary", variant: .primary) {}
            SCButton("Secondary", variant: .secondary) {}
            SCButton("Ghost", variant: .ghost) {}
            SCButton("Delete", variant: .destructive) {}
            SCButton(icon: "sparkles", label: "Sparkles") {}
        }
        HStack(spacing: Spacing.sm) {
            SCButton("Small", size: .small) {}
            SCButton("Medium", size: .medium) {}
            SCButton("Large", size: .large) {}
        }
        SCButton("Disabled", variant: .primary) {}.disabled(true)
    }
    .padding(Spacing.xl)
    .background(Theme.background)
}

#Preview("SCButton — dark") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        SCButton("Primary", variant: .primary) {}
        SCButton("Secondary", variant: .secondary) {}
        SCButton("Disabled", variant: .destructive) {}.disabled(true)
    }
    .padding(Spacing.xl)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
