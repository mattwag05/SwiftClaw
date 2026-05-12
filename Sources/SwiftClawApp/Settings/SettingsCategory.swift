import SwiftUI

/// The six settings destinations shown in the sidebar+detail Settings window.
enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case general, activation, model, tools, memory, appearance, about

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .general: return "General"
        case .activation: return "Activation"
        case .model: return "Model"
        case .tools: return "Tools"
        case .memory: return "Memory"
        case .appearance: return "Appearance"
        case .about: return "About"
        }
    }

    var iconSystemName: String {
        switch self {
        case .general: return "gear"
        case .activation: return "command"
        case .model: return "slider.horizontal.3"
        case .tools: return "wrench.and.screwdriver"
        case .memory: return "brain"
        case .appearance: return "paintpalette"
        case .about: return "info.circle"
        }
    }
}
