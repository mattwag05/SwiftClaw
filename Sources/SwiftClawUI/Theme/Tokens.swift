import SwiftUI

// MARK: - Ink palette

/// The core neutral scale. Dark mode reads from ink-900/950 window backgrounds
/// with translucent white overlays; light mode inverts to near-white backgrounds
/// with translucent black overlays.
public enum Ink {
    public static let ink50  = Color(hex: "#f8f8f8")
    public static let ink100 = Color(hex: "#e8e8e8")
    public static let ink200 = Color(hex: "#d0d0d0")
    public static let ink400 = Color(hex: "#888888")
    public static let ink600 = Color(hex: "#4a4a4a")
    public static let ink800 = Color(hex: "#1f1f1f")
    public static let ink900 = Color(hex: "#0e0e0e")
    public static let ink950 = Color(hex: "#050505")
}

// MARK: - Semantic background tokens

public enum GemmaBackground {
    /// Primary window background (behind all content).
    public static let window = Color(
        light: Color(hex: "#fafafa"),
        dark: Ink.ink950
    )

    /// Content area fill (chat panel, canvas panel).
    public static let fill = Color(
        light: Color(hex: "#f4f4f5"),
        dark: Ink.ink900
    )
}

// MARK: - Surface tints

/// Translucent overlay surfaces — white-on-dark in dark mode,
/// black-on-light in light mode.
public enum Surface {
    public static let s02 = Color(light: .black.opacity(0.030), dark: .white.opacity(0.02))
    public static let s03 = Color(light: .black.opacity(0.040), dark: .white.opacity(0.03))
    public static let s04 = Color(light: .black.opacity(0.050), dark: .white.opacity(0.04))
    public static let s06 = Color(light: .black.opacity(0.060), dark: .white.opacity(0.06))
    public static let s07 = Color(light: .black.opacity(0.070), dark: .white.opacity(0.07))
    public static let s08 = Color(light: .black.opacity(0.080), dark: .white.opacity(0.08))
    public static let s10 = Color(light: .black.opacity(0.100), dark: .white.opacity(0.10))
}

// MARK: - Border tints

public enum GemmaBorder {
    public static let subtle    = Color(light: .black.opacity(0.06), dark: .white.opacity(0.05))
    public static let regular   = Color(light: .black.opacity(0.08), dark: .white.opacity(0.06))
    public static let strong    = Color(light: .black.opacity(0.12), dark: .white.opacity(0.10))
    public static let selected  = Color(light: .black.opacity(0.20), dark: .white.opacity(0.25))
}

// MARK: - Foreground tokens

public enum GemmaForeground {
    /// Primary body text.
    public static let primary = Color(
        light: Ink.ink800,
        dark: Ink.ink100
    )
    /// Secondary / subhead.
    public static let secondary = Color(
        light: Ink.ink600,
        dark: Ink.ink200
    )
    /// Tertiary / placeholder.
    public static let tertiary = Color(
        light: Ink.ink400,
        dark: Ink.ink400
    )
    /// Link blue (Tokyo-night palette).
    public static let link = Color(hex: "#7aa2f7")
}

// MARK: - Accent + semantic tokens

public enum GemmaAccent {
    /// Emerald-400 — running indicators, success checks, active dots.
    public static let emerald = Color(hex: "#34d399")

    public static let error     = Color(light: Color(hex: "#ef4444"), dark: Color(hex: "#f87171"))
    public static let errorFill = Color(light: Color(hex: "#ef4444").opacity(0.10),
                                        dark: Color(hex: "#ef4444").opacity(0.10))
}

// MARK: - Corner-radius constants

public enum GemmaRadius {
    public static let sm:   CGFloat = 6   // pills / chips
    public static let md:   CGFloat = 8   // control surfaces
    public static let lg:   CGFloat = 12  // cards
    public static let xl:   CGFloat = 16  // large cards / user bubble
    public static let bubble: CGFloat = 16  // rounded-2xl
    public static let bubbleTR: CGFloat = 6  // rounded-br-md on user bubble
}

// MARK: - Sidebar geometry

public enum GemmaLayout {
    public static let sidebarWidth: CGFloat = 240
    public static let headerHeight: CGFloat = 44
    public static let composerMaxWidth: CGFloat = 768  // max-w-3xl
    public static let messageMaxWidth: CGFloat = 768
    public static let canvasDefaultWidth: CGFloat = 520
    public static let canvasMinWidth: CGFloat = 320
    public static let canvasMaxWidth: CGFloat = 900
    public static let windowDefaultSize = CGSize(width: 1280, height: 820)
    public static let windowMinSize     = CGSize(width: 820,  height: 560)
}
