import AppKit
import SwiftUI

/// Semantic design tokens for SwiftClawUI.
///
/// Neutral base surfaces with russet (`accent`) and sage (`accentSecondary`)
/// brand hues. Light mode preserves SwiftClaw's warm cream aesthetic; dark mode
/// uses hand-picked neutral tones so the accents read cleanly.
public enum Theme {
    // MARK: - Base surfaces

    /// Window background behind the floating card. Warm cream in light,
    /// near-black neutral in dark.
    public static let background = Color(
        light: Color(hex: "#F5F0E8"),
        dark: Color(hex: "#1A1A1E")
    )

    /// Floating card / primary content surface.
    public static let surface = Color(
        light: Color(hex: "#FFFDF8"),
        dark: Color(hex: "#26262C")
    )

    /// Elevated surface (popovers, sheets, alerts).
    public static let surfaceRaised = Color(
        light: Color(hex: "#FFFDF8"),
        dark: Color(hex: "#2F2F35")
    )

    /// App chrome (sidebar, toolbars). Binds directly to macOS so it tracks
    /// the system window background exactly, including vibrancy.
    public static let chromeBackground = Color(nsColor: .windowBackgroundColor)

    /// Card drop-shadow tint.
    public static let shadow = Color(
        light: Color(red: 0.20, green: 0.15, blue: 0.10).opacity(0.15),
        dark: Color.black.opacity(0.45)
    )

    // MARK: - Foreground

    /// Primary text.
    public static let foregroundPrimary = Color(
        light: Color(hex: "#3B2F2F"),
        dark: Color(hex: "#F1EEE8")
    )

    /// Secondary text (subheads, helper labels at ~70% weight).
    public static var foregroundSecondary: Color {
        foregroundPrimary.opacity(0.70)
    }

    /// Tertiary text (dim monospace labels, placeholders at ~45%).
    public static var foregroundTertiary: Color {
        foregroundPrimary.opacity(0.45)
    }

    // MARK: - Border

    /// Standard hairline border.
    public static let border = Color(
        light: Color(hex: "#5C4033").opacity(0.18),
        dark: Color.white.opacity(0.12)
    )

    /// Subtle divider / inner stroke.
    public static let borderSubtle = Color(
        light: Color(hex: "#5C4033").opacity(0.10),
        dark: Color.white.opacity(0.07)
    )

    // MARK: - Accents

    /// Russet brand accent — primary brand hue.
    public static let accent = Color(
        light: Color(hex: "#8B6F47"),
        dark: Color(hex: "#B88856")
    )

    /// Sage brand accent — secondary brand hue.
    public static let accentSecondary = Color(
        light: Color(hex: "#6B8E5A"),
        dark: Color(hex: "#8EB378")
    )

    /// Deep russet for emphasis / selected nav labels.
    public static let accentDeep = Color(
        light: Color(hex: "#5C4033"),
        dark: Color(hex: "#D4B394")
    )

    /// Warm amber — reserved for annotations, unused in base chrome.
    public static let accentAmber = Color(
        light: Color(hex: "#C87A30"),
        dark: Color(hex: "#E69954")
    )

    // MARK: - Semantic

    public static let destructive = Color(
        light: Color(hex: "#C0392B"),
        dark: Color(hex: "#E57C70")
    )
    public static let success = Color(
        light: Color(hex: "#27AE60"),
        dark: Color(hex: "#4FCC86")
    )
    public static let warning = Color(
        light: Color(hex: "#E67E22"),
        dark: Color(hex: "#FFAF5A")
    )

    // MARK: - Sidebar namespace

    public enum Sidebar {
        /// Sidebar surface. Uses dynamic macOS chrome.
        public static let background = Theme.chromeBackground

        /// Hairline that separates rail / list / detail columns.
        public static let divider = Color(
            light: Color(hex: "#5C4033").opacity(0.12),
            dark: Color.white.opacity(0.08)
        )

        /// Hover / idle row background.
        public static let itemBackground = Color(
            light: Color(hex: "#5C4033").opacity(0.06),
            dark: Color.white.opacity(0.05)
        )

        /// Selected-row ring accent (sage).
        public static let selectedRing = Theme.accentSecondary

        /// Primary sidebar text.
        public static var lightText: Color {
            Theme.foregroundPrimary.opacity(0.85)
        }

        /// Dim sidebar labels (meta, counts, separators).
        public static var dimText: Color {
            Theme.foregroundPrimary.opacity(0.40)
        }

        public static let itemRadius: CGFloat = 8
    }

    // MARK: - Pill namespace

    public enum Pill {
        public static var running: Color {
            Theme.accent.opacity(0.15)
        }

        public static let runningFG = Color(
            light: Color(hex: "#5C4033"),
            dark: Color(hex: "#D4B394")
        )

        public static var pending: Color {
            Theme.accentSecondary.opacity(0.25)
        }

        public static let pendingFG = Color(
            light: Color(hex: "#3D5C2E"),
            dark: Color(hex: "#A9CF93")
        )

        public static var done: Color {
            Theme.success.opacity(0.18)
        }

        public static let doneFG = Color(
            light: Color(hex: "#1A7A35"),
            dark: Color(hex: "#6DDA99")
        )

        public static var error: Color {
            Theme.destructive.opacity(0.14)
        }

        public static var errorFG: Color {
            Theme.destructive
        }

        public static var denied: Color {
            Theme.foregroundPrimary.opacity(0.07)
        }

        public static var deniedFG: Color {
            Theme.foregroundPrimary.opacity(0.40)
        }
    }

    // MARK: - Card / shape constants

    public static let cardCornerRadius: CGFloat = Radius.xl
    public static let bubbleCornerRadius: CGFloat = 18
    public static let inputCornerRadius: CGFloat = Radius.md
    public static let sidebarItemRadius: CGFloat = Sidebar.itemRadius

    // MARK: - Spacing (kept for legacy callers)

    public static let bubblePadding: CGFloat = 10
    public static let inputPadding: CGFloat = 9
    public static let containerPadding: CGFloat = 14
    public static let minimumControlSize: CGFloat = 28
    public static let bubbleMinSpacing: CGFloat = 80
    public static let railWidth: CGFloat = 52
    public static let sidebarWidth: CGFloat = 220

    // MARK: - Typography (legacy fonts — prefer TextStyle modifier)

    public static let captionFont = Font.caption
    public static let bodyFont = Font.body
    public static let monoFont = Font.system(.caption, design: .monospaced)
    public static let monoLabelFont = Font.system(.footnote, design: .monospaced).weight(.semibold)

    // MARK: - Legacy aliases

    //
    // Keep pre-semantic call sites rendering identically in light mode while
    // picking up dark values. Prefer the semantic tokens above for new code.

    public static var brandBlue: Color {
        accent
    }

    public static var brandGold: Color {
        accentSecondary
    }

    public static var brandDeepBlue: Color {
        accentDeep
    }

    public static var brandAmber: Color {
        accentAmber
    }

    public static var windowBackground: Color {
        background
    }

    public static var cardBackground: Color {
        surface
    }

    public static var inputBackground: Color {
        surface
    }

    public static var primaryForeground: Color {
        foregroundPrimary
    }

    /// Legacy `secondaryForeground` rendered at ~0.45 alpha, which maps to
    /// `foregroundTertiary` (not `foregroundSecondary`). Keep it here so the
    /// existing views don't darken when a reader "corrects" the name.
    public static var secondaryForeground: Color {
        foregroundTertiary
    }

    public static var userBubbleBackground: Color {
        accentSecondary
    }

    public static var userBubbleForeground: Color {
        .white
    }

    public static var assistantBubbleBackground: Color {
        .clear
    }

    public static var separatorColor: Color {
        borderSubtle
    }

    public static var errorColor: Color {
        destructive
    }

    public static var warningColor: Color {
        warning
    }

    public static var successColor: Color {
        success
    }

    public static var pillRunning: Color {
        Pill.running
    }

    public static var pillRunningFG: Color {
        Pill.runningFG
    }

    public static var pillPending: Color {
        Pill.pending
    }

    public static var pillPendingFG: Color {
        Pill.pendingFG
    }

    public static var pillDone: Color {
        Pill.done
    }

    public static var pillDoneFG: Color {
        Pill.doneFG
    }

    public static var pillError: Color {
        Pill.error
    }

    public static var pillErrorFG: Color {
        Pill.errorFG
    }

    public static var pillDenied: Color {
        Pill.denied
    }

    public static var pillDeniedFG: Color {
        Pill.deniedFG
    }

    public static var sidebarItemBackground: Color {
        Sidebar.itemBackground
    }

    public static var sidebarSelectedRing: Color {
        Sidebar.selectedRing
    }

    public static var sidebarDivider: Color {
        Sidebar.divider
    }

    public static var sidebarLightText: Color {
        Sidebar.lightText
    }

    public static var sidebarDimText: Color {
        Sidebar.dimText
    }
}

// MARK: - Color helpers

public extension Color {
    /// Parse a hex string like `"#FFDD00"` or `"FFDD00"` into an sRGB color.
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Dynamic color that resolves to `light` under Aqua and `dark` under Dark
    /// Aqua. Responds to `.preferredColorScheme(_:)` because SwiftUI propagates
    /// the appearance into the NSColor resolver.
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
