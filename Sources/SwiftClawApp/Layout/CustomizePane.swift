import SwiftClawUI
import SwiftUI

/// "Customize" view — quick personalization knobs that don't warrant a full
/// settings tab. Wraps the most-changed user preferences in a Perplexity-
/// style card layout.
struct CustomizePane: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .dark
    @AppStorage("sc.commandBarTrigger") private var trigger: String = CommandBarTrigger.bothCommandKeys.rawValue
    @AppStorage("sc.composerFontScale") private var composerFontScale: Double = 1.0
    @AppStorage("sc.showSuggestionChips") private var showSuggestionChips: Bool = true
    @AppStorage("sc.useSerifWordmark") private var useSerifWordmark: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                section(title: "Appearance") {
                    appearanceRow
                    fontSizeRow
                }
                section(title: "Empty state") {
                    settingToggle(
                        "Show suggestion chips",
                        "Display starter prompt chips below the composer.",
                        $showSuggestionChips
                    )
                    settingToggle(
                        "Serif wordmark",
                        "Italic serif lockup matching the original SwiftClaw mark.",
                        $useSerifWordmark
                    )
                }
                section(title: "Command bar") {
                    triggerRow
                }
            }
            .padding(28)
        }
        .background(PXTheme.chatBg)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Customize")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .italic()
                .foregroundStyle(PXTheme.textPrimary)
            Text("Tune SwiftClaw's surface to your taste. Settings apply instantly.")
                .font(.system(size: 13))
                .foregroundStyle(PXTheme.textSecondary)
        }
    }

    // MARK: - Rows

    private var appearanceRow: some View {
        settingRow(title: "Theme", subtitle: "Dark by default — Perplexity-Computer-style.") {
            Picker("", selection: $appearance) {
                ForEach(AppAppearance.allCases, id: \.self) { a in
                    Text(a.rawValue.capitalized).tag(a)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
        }
    }

    private var fontSizeRow: some View {
        settingRow(title: "Composer font size", subtitle: "Scales the input field text.") {
            HStack(spacing: 10) {
                Slider(value: $composerFontScale, in: 0.85 ... 1.30, step: 0.05)
                    .frame(width: 140)
                Text("\(Int(composerFontScale * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(PXTheme.textTertiary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }

    private var triggerRow: some View {
        settingRow(title: "Activation gesture", subtitle: "Hotkey to summon the floating bar.") {
            Picker("", selection: $trigger) {
                ForEach(CommandBarTrigger.allCases, id: \.rawValue) { t in
                    Text(t.label).tag(t.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
        }
    }

    // MARK: - Helpers

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(PXTheme.textTertiary)
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

    private func settingRow<T: View>(title: String, subtitle: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(PXTheme.textTertiary)
            }
            Spacer(minLength: 16)
            trailing()
        }
    }

    private func settingToggle(_ title: String, _ subtitle: String, _ binding: Binding<Bool>) -> some View {
        settingRow(title: title, subtitle: subtitle) {
            Toggle("", isOn: binding).labelsHidden().toggleStyle(.switch)
        }
    }
}
