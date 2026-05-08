import AppKit
import ApplicationServices
import SwiftClawUI
import SwiftUI

/// Activation mechanism for the floating Command Bar.
enum CommandBarTrigger: String, CaseIterable {
    case bothCommandKeys = "both_cmd"
    case shortcut

    var label: String {
        switch self {
        case .bothCommandKeys: return "Both Command Keys"
        case .shortcut: return "⌃⌘ P"
        }
    }
}

/// Settings → Activation. Mirrors Perplexity Computer's activation pane —
/// command bar trigger style, suggestions, sleep prevention, and a "Show
/// Now" button so the user can sanity-check their config.
struct ActivationSettingsView: View {
    @AppStorage("sc.commandBarTrigger") private var trigger: String = CommandBarTrigger.bothCommandKeys.rawValue
    @AppStorage("sc.commandBarSuggestDocs") private var suggestDocs: Bool = true
    @AppStorage("sc.preventSystemSleep") private var preventSleep: Bool = false
    @AppStorage("sc.commandBarMode") private var defaultMode: String = "Last Used"

    private let modes = ["Last Used", "Chat", "Build"]

    @State private var gestureAvailable: Bool = AXIsProcessTrusted()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !gestureAvailable {
                    accessibilityCallout
                }
                section(title: "Command bar") {
                    settingRow(
                        title: "Activation",
                        subtitle: "How to summon the floating command bar."
                    ) {
                        Picker("", selection: $trigger) {
                            ForEach(CommandBarTrigger.allCases, id: \.rawValue) { t in
                                Text(t.label).tag(t.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 240)
                    }

                    settingRow(
                        title: "Default mode",
                        subtitle: "Mode the command bar opens in by default."
                    ) {
                        Picker("", selection: $defaultMode) {
                            ForEach(modes, id: \.self) { m in
                                Text(m).tag(m)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }

                    settingToggle(
                        title: "Suggest open documents",
                        subtitle: "Offer focused windows as context targets when the bar opens.",
                        binding: $suggestDocs
                    )
                }

                section(title: "Power") {
                    settingToggle(
                        title: "Prevent system sleep",
                        subtitle: "Keeps your Mac awake while a generation is in flight.",
                        binding: $preventSleep
                    )
                }

                section(title: "Test it") {
                    HStack {
                        Button {
                            NotificationCenter.default.post(name: .pxSummonCommandBar, object: nil)
                        } label: {
                            Label("Show command bar now", systemImage: "command.circle")
                                .frame(minWidth: 220)
                        }
                        .keyboardShortcut("p", modifiers: [.command, .control])
                        Spacer()
                        Text("⌃⌘ P")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(PXTheme.textTertiary)
                    }
                }
            }
            .padding(28)
        }
    }

    private var accessibilityCallout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(PXTheme.warning)
                Text("Accessibility access required for double-Command gesture")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PXTheme.textPrimary)
            }
            Text("The ⌃⌘P shortcut works without Accessibility, but the “press both Command keys” gesture won't fire until you grant access in System Settings → Privacy & Security → Accessibility.")
                .font(.system(size: 11.5))
                .foregroundStyle(PXTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Re-check") {
                    GlobalHotkeyMonitor.requestAccessibilityIfNeeded()
                    gestureAvailable = AXIsProcessTrusted()
                }
            }
            .controlSize(.small)
        }
        .padding(14)
        .background(PXTheme.warning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: PXTheme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PXTheme.Radius.card, style: .continuous)
                .strokeBorder(PXTheme.warning.opacity(0.30), lineWidth: 1)
        )
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(PXTheme.textTertiary)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(16)
            .background(PXTheme.surface1)
            .clipShape(RoundedRectangle(cornerRadius: PXTheme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PXTheme.Radius.card, style: .continuous)
                    .strokeBorder(PXTheme.borderHairline, lineWidth: 1)
            )
        }
    }

    private func settingRow<Trailing: View>(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(PXTheme.textTertiary)
            }
            Spacer(minLength: 16)
            trailing()
        }
    }

    private func settingToggle(title: String, subtitle: String, binding: Binding<Bool>) -> some View {
        settingRow(title: title, subtitle: subtitle) {
            Toggle("", isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}
