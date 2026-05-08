import SwiftUI

/// Visual design tokens for the Perplexity-Computer-inspired SwiftClaw UI.
///
/// This namespace is additive on top of the existing `Theme` / `Gemma*` tokens
/// so the legacy views keep compiling. New views (`Perplexity*`) read from
/// here for their colors, geometry, and motion.
public enum PXTheme {
    // MARK: - Surfaces

    /// Outermost window background — near-black with a hint of warmth.
    public static let windowBg = Color(
        light: Color(hex: "#fafafa"),
        dark: Color(hex: "#0c0c0d")
    )

    /// Sidebar background — slightly elevated above the window.
    public static let sidebarBg = Color(
        light: Color(hex: "#f3f3f4"),
        dark: Color(hex: "#131315")
    )

    /// Main chat pane background — sits between window and elevated surfaces.
    public static let chatBg = Color(
        light: Color(hex: "#ffffff"),
        dark: Color(hex: "#0f0f11")
    )

    /// Card / input background — first elevated surface.
    public static let surface1 = Color(
        light: Color(hex: "#f5f5f6"),
        dark: Color(hex: "#1a1a1d")
    )

    /// Hover / selected state on top of `surface1`.
    public static let surface2 = Color(
        light: Color(hex: "#ececee"),
        dark: Color(hex: "#23232a")
    )

    /// Even more elevated surface (popovers, command bar).
    public static let surface3 = Color(
        light: Color(hex: "#ffffff"),
        dark: Color(hex: "#26262d")
    )

    // MARK: - Borders

    public static let borderHairline = Color(
        light: .black.opacity(0.06),
        dark: .white.opacity(0.06)
    )

    public static let borderRegular = Color(
        light: .black.opacity(0.10),
        dark: .white.opacity(0.10)
    )

    public static let borderStrong = Color(
        light: .black.opacity(0.16),
        dark: .white.opacity(0.18)
    )

    // MARK: - Foreground

    public static let textPrimary = Color(
        light: Color(hex: "#1a1a1d"),
        dark: Color(hex: "#fafafb")
    )

    public static let textSecondary = Color(
        light: Color(hex: "#5a5a60"),
        dark: Color(hex: "#b5b5bb")
    )

    public static let textTertiary = Color(
        light: Color(hex: "#86868c"),
        dark: Color(hex: "#7d7d83")
    )

    public static let textPlaceholder = Color(
        light: Color(hex: "#a8a8ae"),
        dark: Color(hex: "#5d5d63")
    )

    // MARK: - Accent

    /// SwiftClaw "Tropical Storm" — kept distinct from Perplexity's exact teal
    /// while occupying the same UI role (send button, focused chip, active
    /// state). Slightly more saturated cyan-blue than Perplexity's #21808d.
    public static let accent = Color(hex: "#1ea7b5")

    /// A softer accent fill used behind active pills and selected chips.
    public static let accentSoft = accent.opacity(0.16)

    /// Foreground used on the accent button (always near-white).
    public static let onAccent = Color.white

    // MARK: - Status

    public static let success = Color(hex: "#34d399")
    public static let warning = Color(hex: "#fbbf24")
    public static let danger = Color(hex: "#ef4444")

    // MARK: - Geometry

    public enum Radius {
        public static let chip: CGFloat = 8
        public static let button: CGFloat = 10
        public static let card: CGFloat = 14
        public static let input: CGFloat = 16
        public static let dialog: CGFloat = 18
        public static let window: CGFloat = 14
    }

    public enum Layout {
        public static let sidebarWidth: CGFloat = 240
        public static let composerMaxWidth: CGFloat = 720
        public static let transcriptMaxWidth: CGFloat = 760
        public static let windowDefaultSize = CGSize(width: 1180, height: 760)
        public static let windowMinSize = CGSize(width: 920, height: 600)
        public static let commandBarSize = CGSize(width: 720, height: 132)
    }

    // MARK: - Motion

    public enum Motion {
        public static let snap = Animation.spring(response: 0.28, dampingFraction: 0.86)
        public static let smooth = Animation.spring(response: 0.40, dampingFraction: 0.92)
        public static let quick = Animation.easeOut(duration: 0.18)
        public static let pop = Animation.spring(response: 0.32, dampingFraction: 0.72)
    }
}

// MARK: - Wordmark

/// SwiftClaw wordmark, mimicking the "perplexity.pro" lockup from the
/// Perplexity Computer empty state — serif italic display type with a
/// small product-tier suffix.
public struct PXWordmark: View {
    public var tier: String?

    public init(tier: String? = "swift") {
        self.tier = tier
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("swiftclaw")
                .font(.system(size: 44, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(PXTheme.textSecondary.opacity(0.78))
            if let tier {
                Text(tier)
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(PXTheme.textTertiary)
                    .padding(.leading, 2)
                    .offset(y: -2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("SwiftClaw")
    }
}
