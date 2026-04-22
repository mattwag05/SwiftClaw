import SwiftClawUI
import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @AppStorage(MessageStyle.storageKey) private var messageStyle: MessageStyle = .bubbles

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Mode", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Chat Transcript") {
                Picker("Message Style", selection: $messageStyle) {
                    ForEach(MessageStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Text(messageStyle == .bubbles
                    ? "Classic bubble layout; groups consecutive tool calls."
                    : "Flat timeline with a left rail and connector dots.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
