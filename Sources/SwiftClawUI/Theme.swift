import SwiftUI
import AppKit

/// Semantic design tokens for SwiftClawUI.
/// Palette extracted from the SwiftClaw app icon:
///   Sky blue  #4AABDF  — primary brand color
///   Gold      #F5C842  — accent / highlight
///   Deep blue #1A6FA8  — dark background / shadows
///   Amber     #C87A30  — warm accent
public enum Theme {

    // MARK: - Brand palette

    public static let brandBlue     = Color(hex: "#4AABDF")
    public static let brandGold     = Color(hex: "#F5C842")
    public static let brandDeepBlue = Color(hex: "#1A6FA8")
    public static let brandAmber    = Color(hex: "#C87A30")

    // MARK: - Window / card

    /// Dark deep-blue window background (matches icon background)
    public static let windowBackground = Color(hex: "#0F2A3D")

    /// Floating light card background
    public static let cardBackground = Color(red: 0.96, green: 0.97, blue: 0.98)

    public static let cardCornerRadius: CGFloat = 20

    // MARK: - Text (on light card)

    public static let primaryForeground   = Color(hex: "#1A2530")
    public static let secondaryForeground = Color(hex: "#1A2530").opacity(0.45)

    // MARK: - Chat bubbles

    /// User bubble: brand blue pill
    public static let userBubbleBackground = brandBlue
    public static let userBubbleForeground = Color.white

    /// Assistant: plain text on card, no bubble
    public static let assistantBubbleBackground = Color.clear

    // MARK: - Status pill colors

    public static let pillRunning    = Color(hex: "#4AABDF").opacity(0.15)
    public static let pillRunningFG  = Color(hex: "#1A6FA8")
    public static let pillPending    = Color(hex: "#F5C842").opacity(0.25)
    public static let pillPendingFG  = Color(hex: "#8A6A00")
    public static let pillDone       = Color(hex: "#34C759").opacity(0.15)
    public static let pillDoneFG     = Color(hex: "#1A7A35")
    public static let pillError      = Color.red.opacity(0.12)
    public static let pillErrorFG    = Color(hex: "#C0392B")
    public static let pillDenied     = Color.black.opacity(0.07)
    public static let pillDeniedFG   = Color(hex: "#1A2530").opacity(0.4)

    // MARK: - Input bar

    public static let inputBackground  = Color.white
    public static let separatorColor   = Color.black.opacity(0.08)

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
    public static let sidebarItemBackground  = Color.white.opacity(0.06)
    public static let sidebarSelectedRing    = brandGold
    public static let sidebarDivider         = Color.white.opacity(0.08)
    public static let sidebarLightText       = Color.white.opacity(0.7)
    public static let sidebarDimText         = Color.white.opacity(0.35)

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
