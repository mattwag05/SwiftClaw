import SwiftClawUI
import SwiftUI

/// Modal sheet that hosts `SCCommand` and injects the live command list.
struct CommandPaletteView: View {
    @Environment(ChatViewModel.self) private var viewModel
    @Environment(CommandRegistry.self) private var registry

    let onOpenSettings: () -> Void
    let onToggleSidebar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Command Palette")
                .textStyle(.captionEmph)
                .foregroundStyle(Theme.foregroundSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)

            SCCommand(
                items: Commands.all(
                    viewModel: viewModel,
                    onOpenSettings: onOpenSettings,
                    onToggleSidebar: onToggleSidebar,
                    onDismiss: { registry.dismiss() }
                ),
                onDismiss: { registry.dismiss() }
            )
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.sm)
        }
        .frame(width: 520, height: 400)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Theme.surfaceRaised)
        )
    }
}
