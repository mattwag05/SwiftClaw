import SwiftUI
import AppKit

/// Semantic design tokens for SwiftClawUI.
/// Warm russet-inspired palette — cream tones, sage accents, deep brown.
public enum Theme {

    // MARK: - Brand palette

    public static let brandBlue     = Color(hex: "#8B6F47")  // warm brown (was sky blue)
    public static let brandGold     = Color(hex: "#6B8E5A")  // sage green (was yellow-gold)
    public static let brandDeepBlue = Color(hex: "#5C4033")  // deep brown (was deep blue)
    public static let brandAmber    = Color(hex: "#C87A30")  // warm amber (unchanged)

    // MARK: - Window / card

    /// Warm cream window background
    public static let windowBackground = Color(hex: "#F5F0E8")

    /// Warm white floating card background
    public static let cardBackground = Color(hex: "#FFFDF8")

    public static let cardCornerRadius: CGFloat = 20

    // MARK: - Text (on light card)

    public static let primaryForeground   = Color(hex: "#3B2F2F")
    public static let secondaryForeground = Color(hex: "#3B2F2F").opacity(0.45)

    // MARK: - Chat bubbles

    /// User bubble: sage green pill
    public static let userBubbleBackground = brandGold
    public static let userBubbleForeground = Color.white

    /// Assistant: plain text on card, no bubble
    public static let assistantBubbleBackground = Color.clear

    // MARK: - Status pill colors

    public static let pillRunning    = Color(hex: "#8B6F47").opacity(0.15)
    public static let pillRunningFG  = Color(hex: "#5C4033")
    public static let pillPending    = Color(hex: "#6B8E5A").opacity(0.25)
    public static let pillPendingFG  = Color(hex: "#3D5C2E")
    public static let pillDone       = Color(hex: "#34C759").opacity(0.15)
    public static let pillDoneFG     = Color(hex: "#1A7A35")
    public static let pillError      = Color.red.opacity(0.12)
    public static let pillErrorFG    = Color(hex: "#C0392B")
    public static let pillDenied     = Color(hex: "#3B2F2F").opacity(0.07)
    public static let pillDeniedFG   = Color(hex: "#3B2F2F").opacity(0.4)

    // MARK: - Input bar

    public static let inputBackground  = Color(hex: "#FFFDF8")
    public static let separatorColor   = Color(hex: "#5C4033").opacity(0.10)

    // MARK: - Misc

    public static let errorColor   = Color(hex: "#C0392B")
    public static let warningColor = Color(hex: "#E67E22")
    public static let successColor = Color(hex: "#27AE60")

    // MARK: - Spacing

    public static let bubblePadding: CGFloat       = 10
    public static let bubbleCornerRadius: CGFloat  = 18
    public static let inputCornerRadius: CGFloat   = 10
    public static let inputPadding: CGFloat        = 9
    public static let containerPadding: CGFloat    = 14
    public static let minimumControlSize: CGFloat  = 28

    // MARK: - Typography

    public static let captionFont     = Font.caption
    public static let bodyFont        = Font.body
    public static let monoFont        = Font.system(.caption, design: .monospaced)
    public static let monoLabelFont   = Font.system(.footnote, design: .monospaced).weight(.semibold)

    // MARK: - Sidebar

    public static let railWidth: CGFloat     = 52
    public static let sidebarWidth: CGFloat  = 220
    public static let sidebarItemRadius: CGFloat = 8
    public static let sidebarItemBackground  = Color(hex: "#5C4033").opacity(0.06)
    public static let sidebarSelectedRing    = brandGold
    public static let sidebarDivider         = Color(hex: "#5C4033").opacity(0.12)
    public static let sidebarLightText       = Color(hex: "#3B2F2F").opacity(0.85)
    public static let sidebarDimText         = Color(hex: "#3B2F2F").opacity(0.40)

    // MARK: - Layout

    public static let bubbleMinSpacing: CGFloat = 80
}

// MARK: - Hex color convenience

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
