import SwiftUI

/// Semantic text-style scale for SwiftClawUI.
///
/// Apply with `.textStyle(.body)` rather than `.font(.body)` so line height
/// and letter-spacing come along with the font. Per-style values are chosen
/// to read well against the warm light card and neutral dark surface.
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

    public var font: Font {
        switch self {
        case .display: return .system(size: 28, weight: .bold, design: .default)
        case .heading: return .system(size: 20, weight: .semibold, design: .default)
        case .subheading: return .system(size: 15, weight: .semibold, design: .default)
        case .body: return .system(size: 14, weight: .regular, design: .default)
        case .bodyEmph: return .system(size: 14, weight: .semibold, design: .default)
        case .caption: return .system(size: 11, weight: .regular, design: .default)
        case .captionEmph: return .system(size: 11, weight: .semibold, design: .default)
        case .codeInline: return .system(size: 13, weight: .regular, design: .monospaced)
        case .codeBlock: return .system(size: 12, weight: .regular, design: .monospaced)
        case .monoLabel: return .system(size: 11, weight: .semibold, design: .monospaced)
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
}

public extension View {
    /// Apply font, line spacing, and letter spacing for a semantic text style.
    func textStyle(_ style: TextStyle) -> some View {
        font(style.font)
            .lineSpacing(style.lineSpacing)
            .tracking(style.letterSpacing)
    }
}
