import AppKit
import SwiftUI

/// Semantic design tokens for SwiftClawUI.
///
/// Rebuilt on the Gemma Chat ink palette. All legacy call sites continue to
/// compile — the semantic names are preserved, values redirect to `Ink`,
/// `Surface`, `GemmaBorder`, and `GemmaForeground`.
public enum Theme {
    // MARK: - Base surfaces

    public static let background     = GemmaBackground.window
    public static let surface        = Color(light: .white, dark: Surface.s04)
    public static let surfaceRaised  = Color(light: .white, dark: Surface.s06)
    public static let chromeBackground = Color(nsColor: .windowBackgroundColor)
    public static let shadow         = Color(
        light: Color.black.opacity(0.08),
        dark:  Color.black.opacity(0.45)
    )

    // MARK: - Foreground

    public static let foregroundPrimary   = GemmaForeground.primary
    public static var foregroundSecondary: Color { GemmaForeground.secondary }
    public static var foregroundTertiary:  Color { GemmaForeground.tertiary }

    // MARK: - Border

    public static let border       = GemmaBorder.regular
    public static let borderSubtle = GemmaBorder.subtle

    // MARK: - Accents — mapped to emerald / neutral for semantic use

    /// Primary accent. Maps to emerald (Gemma's running / active green).
    public static let accent          = GemmaAccent.emerald
    /// Secondary accent. Neutral tint for secondary affordances.
    public static let accentSecondary = Color(light: Ink.ink400, dark: Ink.ink400)
    public static let accentDeep      = Color(light: Ink.ink600, dark: Ink.ink200)
    public static let accentAmber     = Color(
        light: Color(hex: "#f59e0b"),
        dark:  Color(hex: "#fbbf24")
    )

    // MARK: - Semantic status

    public static let destructive = GemmaAccent.error
    public static let success     = GemmaAccent.emerald
    public static let warning     = Color(
        light: Color(hex: "#f59e0b"),
        dark:  Color(hex: "#fbbf24")
    )

    // MARK: - Sidebar

    public enum Sidebar {
        public static let background      = Theme.chromeBackground
        public static let divider         = GemmaBorder.subtle
        public static let itemBackground  = Surface.s04
        public static let selectedRing    = GemmaAccent.emerald
        public static var lightText: Color { GemmaForeground.primary }
        public static var dimText:   Color { GemmaForeground.tertiary }
        public static let itemRadius: CGFloat = GemmaRadius.md
    }

    // MARK: - Pill

    public enum Pill {
        public static var running:   Color { GemmaAccent.emerald.opacity(0.15) }
        public static let runningFG  = GemmaAccent.emerald
        public static var pending:   Color { Surface.s06 }
        public static let pendingFG  = GemmaForeground.secondary
        public static var done:      Color { GemmaAccent.emerald.opacity(0.15) }
        public static let doneFG     = GemmaAccent.emerald
        public static var error:     Color { GemmaAccent.errorFill }
        public static var errorFG:   Color { GemmaAccent.error }
        public static var denied:    Color { Surface.s04 }
        public static var deniedFG:  Color { GemmaForeground.tertiary }
    }

    // MARK: - Shape constants

    public static let cardCornerRadius:    CGFloat = GemmaRadius.lg
    public static let bubbleCornerRadius:  CGFloat = GemmaRadius.bubble
    public static let inputCornerRadius:   CGFloat = GemmaRadius.md
    public static let sidebarItemRadius:   CGFloat = Sidebar.itemRadius

    // MARK: - Spacing / geometry (legacy)

    public static let bubblePadding:      CGFloat = 10
    public static let inputPadding:       CGFloat = 9
    public static let containerPadding:   CGFloat = 14
    public static let minimumControlSize: CGFloat = 28
    public static let bubbleMinSpacing:   CGFloat = 80
    public static let railWidth:          CGFloat = 52
    public static let sidebarWidth:       CGFloat = GemmaLayout.sidebarWidth

    // MARK: - Legacy font aliases

    public static let captionFont    = Font.caption
    public static let bodyFont       = Font.body
    public static let monoFont       = Font.system(.caption, design: .monospaced)
    public static let monoLabelFont  = Font.system(.footnote, design: .monospaced).weight(.semibold)

    // MARK: - Legacy color aliases (keep compiling)

    public static var brandBlue:    Color { accent }
    public static var brandGold:    Color { accentSecondary }
    public static var brandDeepBlue: Color { accentDeep }
    public static var brandAmber:   Color { accentAmber }
    public static var windowBackground:       Color { background }
    public static var cardBackground:         Color { surface }
    public static var inputBackground:        Color { surface }
    public static var primaryForeground:      Color { foregroundPrimary }
    public static var secondaryForeground:    Color { foregroundTertiary }
    public static var userBubbleBackground:   Color { Surface.s08 }
    public static var userBubbleForeground:   Color { foregroundPrimary }
    public static var assistantBubbleBackground: Color { .clear }
    public static var separatorColor:         Color { borderSubtle }
    public static var errorColor:             Color { destructive }
    public static var warningColor:           Color { warning }
    public static var successColor:           Color { success }

    public static var pillRunning:   Color { Pill.running }
    public static var pillRunningFG: Color { Pill.runningFG }
    public static var pillPending:   Color { Pill.pending }
    public static var pillPendingFG: Color { Pill.pendingFG }
    public static var pillDone:      Color { Pill.done }
    public static var pillDoneFG:    Color { Pill.doneFG }
    public static var pillError:     Color { Pill.error }
    public static var pillErrorFG:   Color { Pill.errorFG }
    public static var pillDenied:    Color { Pill.denied }
    public static var pillDeniedFG:  Color { Pill.deniedFG }

    public static var sidebarItemBackground: Color { Sidebar.itemBackground }
    public static var sidebarSelectedRing:   Color { Sidebar.selectedRing }
    public static var sidebarDivider:        Color { Sidebar.divider }
    public static var sidebarLightText:      Color { Sidebar.lightText }
    public static var sidebarDimText:        Color { Sidebar.dimText }
}

// MARK: - Color helpers

public extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            switch appearance.name {
            case .darkAqua,
                 .vibrantDark,
                 .accessibilityHighContrastDarkAqua,
                 .accessibilityHighContrastVibrantDark:
                return NSColor(dark)
            default:
                return NSColor(light)
            }
        })
    }
}
