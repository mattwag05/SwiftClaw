import SwiftUI

/// How the chat transcript is rendered.
///
/// Persisted via `@AppStorage(MessageStyle.storageKey)`. `ChatDetailView` reads
/// this and chooses between the classic bubble list and the flat timeline.
public enum MessageStyle: String, CaseIterable, Identifiable, Sendable {
    case bubbles
    case timeline

    public static let storageKey = "sc.messageStyle"

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .bubbles: return "Bubbles"
        case .timeline: return "Timeline"
        }
    }
}
