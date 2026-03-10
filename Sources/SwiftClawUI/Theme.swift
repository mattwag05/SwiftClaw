import SwiftUI
import AppKit

/// Semantic design tokens for SwiftClawUI.
/// All values use system colors and adapt to light/dark mode automatically.
public enum Theme {

    // MARK: - Colors (semantic, system-adaptive)

    /// Primary text / foreground
    public static let primaryForeground = Color.primary

    /// Secondary text / icons
    public static let secondaryForeground = Color.secondary

    /// User message bubble background
    public static let userBubbleBackground = Color.accentColor.opacity(0.85)

    /// User message bubble foreground
    public static let userBubbleForeground = Color.white

    /// Assistant message bubble background
    public static let assistantBubbleBackground = Color(nsColor: .windowBackgroundColor)

    /// Input bar background
    public static let inputBackground = Color(nsColor: .controlBackgroundColor)

    /// Error / destructive
    public static let errorColor = Color.red

    /// Warning
    public static let warningColor = Color.orange

    /// Success / positive
    public static let successColor = Color.green

    // MARK: - Spacing

    public static let bubblePadding: CGFloat = 10
    public static let bubbleCornerRadius: CGFloat = 12
    public static let inputCornerRadius: CGFloat = 8
    public static let inputPadding: CGFloat = 8
    public static let containerPadding: CGFloat = 12
    public static let minimumControlSize: CGFloat = 28

    // MARK: - Typography

    public static let captionFont = Font.caption
    public static let bodyFont = Font.body
    public static let monoFont = Font.system(.caption, design: .monospaced)

    // MARK: - Sidebar minimum bubble spacing
    public static let bubbleMinSpacing: CGFloat = 60
}
