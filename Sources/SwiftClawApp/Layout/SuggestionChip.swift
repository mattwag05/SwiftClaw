import SwiftClawUI
import SwiftUI

/// Pill-shaped starter prompt chip shown beneath the empty-state composer.
///
/// Hovering reveals an accent border and lifts the chip 1pt — small physical
/// cue that matches Perplexity Computer's chip motion.
struct SuggestionChip: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var hovering: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(hovering ? PXTheme.accent : PXTheme.textTertiary)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(hovering ? PXTheme.textPrimary : PXTheme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(hovering ? PXTheme.surface2 : PXTheme.surface1.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .strokeBorder(hovering ? PXTheme.borderRegular : PXTheme.borderHairline, lineWidth: 1)
            )
            .offset(y: hovering ? -1 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(PXTheme.Motion.quick, value: hovering)
    }
}
