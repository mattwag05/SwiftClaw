import SwiftClawUI
import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "bird")
                .font(.system(size: 48))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)

            Text("SwiftClaw")
                .textStyle(.heading)

            Text(versionString)
                .textStyle(.caption)
                .foregroundStyle(Theme.foregroundSecondary)

            Divider()
                .padding(.horizontal, Spacing.xxl)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("macOS-native AI agent framework")
                    .textStyle(.body)
                Text("MLX on-device inference, tool approval, session store")
                    .textStyle(.caption)
                    .foregroundStyle(Theme.foregroundSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }

    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, build != short {
            return "Version \(short) (\(build))"
        }
        return "Version \(short)"
    }
}
