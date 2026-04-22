import Foundation
import Observation

/// Tracks whether the ⌘K command palette is currently presented.
///
/// Injected into the SwiftUI environment so menu commands, keyboard
/// shortcuts, and arbitrary views can toggle the palette without threading
/// bindings through every layer.
@Observable
@MainActor
final class CommandRegistry {
    var isPresented: Bool = false

    func toggle() {
        isPresented.toggle()
    }

    func show() {
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }
}
