import SwiftClawCore
import SwiftClawUI
import SwiftUI

/// Sidebar nav row with proper hover state. Each row maintains its own
/// hover flag so a single instance never lights up a sibling.
struct NavRow: View {
    let title: String
    let systemImage: String
    let active: Bool
    let action: () -> Void

    @State private var hovering: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 12.5, weight: active ? .semibold : .regular))
                    .foregroundStyle(textColor)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(background)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var iconColor: Color {
        if active { return PXTheme.accent }
        if hovering { return PXTheme.textPrimary }
        return PXTheme.textSecondary
    }

    private var textColor: Color {
        if active { return PXTheme.textPrimary }
        if hovering { return PXTheme.textPrimary }
        return PXTheme.textSecondary
    }

    private var background: Color {
        if active { return PXTheme.surface2.opacity(0.7) }
        if hovering { return PXTheme.surface1.opacity(0.5) }
        return .clear
    }
}

/// Session row with proper hover state.
struct SessionRow: View {
    let summary: SessionSummary
    let active: Bool
    let action: () -> Void

    @State private var hovering: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if summary.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(PXTheme.accent)
                        .frame(width: 8)
                }
                Text(summary.displayTitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(active ? PXTheme.textPrimary : (hovering ? PXTheme.textPrimary : PXTheme.textSecondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(active ? PXTheme.surface2 : (hovering ? PXTheme.surface1.opacity(0.5) : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { hovering = $0 }
    }
}
