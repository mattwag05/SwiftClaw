import SwiftUI

/// Spacing scale for SwiftClawUI.
///
/// Use these for padding, gaps, and control heights. Values step on an 8pt
/// rhythm with a 4pt half-step for tight controls; custom non-standard values
/// should be rare and named at the call site.
public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

/// Corner-radius scale for SwiftClawUI.
public enum Radius {
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 10
    public static let lg: CGFloat = 14
    public static let xl: CGFloat = 20
}
