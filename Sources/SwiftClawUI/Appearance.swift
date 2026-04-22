import SwiftUI

/// User-selected appearance preference for the SwiftClaw app.
///
/// Persisted via `@AppStorage("sc.appearance")`. The root scene reads this and
/// applies `.preferredColorScheme(_:)` so every Color(light:dark:) token and
/// dynamic NSColor resolves correctly. `.system` yields `nil`, leaving macOS
/// in charge.
public enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    /// `@AppStorage` key used in every call site.
    public static let storageKey = "sc.appearance"

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
