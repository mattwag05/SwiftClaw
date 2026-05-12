import SwiftUI

/// Semantic text-style scale for SwiftClawUI (Gemma Chat visual refresh).
///
/// Apply with `.textStyle(.body)` — the modifier layers Dynamic Type scaling,
/// line spacing, and tracking on top of the font. Raw `.font` property is
/// available for non-View contexts.
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
    /// Activity bar / hint labels (11.5pt).
    case activity
    /// Tabular-numerals mono for elapsed time and byte counts.
    case tabularMono

    public var baseSize: CGFloat {
        switch self {
        case .display:            return 32
        case .heading:            return 22
        case .subheading:         return 15
        case .body, .bodyEmph:    return 14.5
        case .codeInline:         return 13
        case .codeBlock:          return 12
        case .caption, .captionEmph: return 11.5
        case .monoLabel:          return 11.5
        case .activity:           return 11.5
        case .tabularMono:        return 11.5
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .display:                            return .bold
        case .heading, .subheading, .bodyEmph,
             .captionEmph, .monoLabel:           return .semibold
        case .body, .caption, .codeInline,
             .codeBlock, .activity, .tabularMono: return .regular
        }
    }

    public var design: Font.Design {
        switch self {
        case .codeInline, .codeBlock, .monoLabel,
             .tabularMono:                        return .monospaced
        default:                                  return .default
        }
    }

    public var dynamicTypeAnchor: Font.TextStyle {
        switch self {
        case .display:            return .largeTitle
        case .heading:            return .title2
        case .subheading:         return .subheadline
        case .body, .bodyEmph, .codeInline: return .body
        case .codeBlock:          return .callout
        case .caption, .captionEmph, .monoLabel,
             .activity, .tabularMono:       return .caption
        }
    }

    /// Additional line spacing (not the full leading — just extra gap).
    /// Body uses 1.6 line-height: extra = baseSize * 0.6 ≈ 8.7 → 8pt.
    public var lineSpacing: CGFloat {
        switch self {
        case .display:            return 6
        case .heading:            return 4
        case .subheading:         return 3
        case .body, .bodyEmph:    return 8    // 14.5 * 0.6 ≈ 8.7 → targets 1.6 line-height
        case .codeInline:         return 4
        case .codeBlock:          return 4    // 12 * 0.55 ≈ 6.6, split with system leading
        case .caption, .captionEmph: return 2
        case .monoLabel, .activity, .tabularMono: return 1
        }
    }

    public var letterSpacing: CGFloat {
        switch self {
        case .display:            return -0.4
        case .heading:            return -0.2
        case .monoLabel:          return 0.4
        default:                  return 0
        }
    }

    public var font: Font {
        .system(size: baseSize, weight: weight, design: design)
    }
}

// MARK: - View modifier

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
        let scale = scaledSize / style.baseSize
        return content
            .font(.system(size: scaledSize, weight: style.weight, design: style.design))
            .lineSpacing(style.lineSpacing * scale)
            .tracking(style.letterSpacing * scale)
    }
}

public extension View {
    func textStyle(_ style: TextStyle) -> some View {
        modifier(TextStyleModifier(style: style))
    }
}
