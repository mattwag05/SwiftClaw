import SwiftUI

/// Semantic text-style scale for SwiftClawUI.
///
/// Apply with `.textStyle(.body)` rather than `.font(.body)` so line height,
/// letter-spacing, **and Dynamic Type scaling** come along with the font. The
/// `.textStyle(_:)` view modifier wraps the point size in a `@ScaledMetric`
/// anchored to a matching `Font.TextStyle`, so text responds to the user's
/// system text-size setting. Line-spacing and tracking are scaled
/// proportionally so the visual rhythm is preserved at any Dynamic Type size.
///
/// Each `TextStyle` case exposes its component parts (`baseSize`, `weight`,
/// `design`, `dynamicTypeAnchor`, `lineSpacing`, `letterSpacing`) so callers
/// who need a raw `Font` (outside a `View` context) can compose one via `font`;
/// that form is non-scaling and should be reserved for cases where the view
/// modifier can't be used.
public enum TextStyle: Hashable, Sendable {
    case display
    case heading
    case subheading
    case body
    case bodyEmph
    case caption
    case captionEmph
    case codeInline
    case codeBlock
    case monoLabel

    /// Point size at the default Dynamic Type setting (`.large`). The
    /// rendered size is this value scaled for the user's current
    /// Dynamic Type size via `@ScaledMetric`.
    public var baseSize: CGFloat {
        switch self {
        case .display: return 28
        case .heading: return 20
        case .subheading: return 15
        case .body, .bodyEmph: return 14
        case .codeInline: return 13
        case .codeBlock: return 12
        case .caption, .captionEmph, .monoLabel: return 11
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .display: return .bold
        case .heading, .subheading, .bodyEmph, .captionEmph, .monoLabel:
            return .semibold
        case .body, .caption, .codeInline, .codeBlock:
            return .regular
        }
    }

    public var design: Font.Design {
        switch self {
        case .codeInline, .codeBlock, .monoLabel: return .monospaced
        default: return .default
        }
    }

    /// The system text style this custom size scales relative to. Choosing a
    /// close-in-size anchor keeps the scaling ratio reasonable across the full
    /// Dynamic Type range (`.xSmall` through `.accessibility5`).
    public var dynamicTypeAnchor: Font.TextStyle {
        switch self {
        case .display: return .largeTitle
        case .heading: return .title2
        case .subheading: return .subheadline
        case .body, .bodyEmph, .codeInline: return .body
        case .codeBlock: return .callout
        case .caption, .captionEmph, .monoLabel: return .caption
        }
    }

    public var lineSpacing: CGFloat {
        switch self {
        case .display: return 4
        case .heading: return 3
        case .subheading, .body, .bodyEmph: return 2
        case .codeInline, .codeBlock: return 2
        case .caption, .captionEmph,
             .monoLabel: return 1
        }
    }

    public var letterSpacing: CGFloat {
        switch self {
        case .display: return -0.4
        case .heading: return -0.2
        case .monoLabel: return 0.5
        default: return 0
        }
    }

    /// Non-scaling `Font` composed from this style's base size, weight, and
    /// design. Prefer the `.textStyle(_:)` view modifier, which layers
    /// Dynamic Type scaling on top. Use this property only when a raw `Font`
    /// is required outside a `View` context.
    public var font: Font {
        .system(size: baseSize, weight: weight, design: design)
    }
}

/// View modifier that applies a `TextStyle` with Dynamic-Type-scaled size,
/// line spacing, and tracking.
///
/// `@ScaledMetric` is initialized lazily per instance — the `relativeTo:`
/// anchor is chosen from the style's `dynamicTypeAnchor` so each style scales
/// with a sensible reference (e.g. `.display` tracks `.largeTitle`).
private struct TextStyleModifier: ViewModifier {
    let style: TextStyle
    @ScaledMetric private var scaledSize: CGFloat

    init(style: TextStyle) {
        self.style = style
        _scaledSize = ScaledMetric(
            wrappedValue: style.baseSize,
            relativeTo: style.dynamicTypeAnchor
        )
    }

    func body(content: Content) -> some View {
        // Proportional scale so lineSpacing + tracking keep their relationship
        // to the font size across Dynamic Type sizes.
        let scale = scaledSize / style.baseSize
        return content
            .font(.system(size: scaledSize, weight: style.weight, design: style.design))
            .lineSpacing(style.lineSpacing * scale)
            .tracking(style.letterSpacing * scale)
    }
}

public extension View {
    /// Apply font, line spacing, and letter spacing for a semantic text style.
    ///
    /// Text scales with the user's Dynamic Type setting. See `TextStyle` for
    /// the full scale and per-case anchors.
    func textStyle(_ style: TextStyle) -> some View {
        modifier(TextStyleModifier(style: style))
    }
}
