import AppKit
import SwiftUI

/// Horizontal split with a draggable divider between two views.
///
/// The left child has an explicit `leftWidth` (bound), clamped to
/// `[minLeft, maxLeft]`. The right child fills the remaining horizontal
/// space. A 6pt divider sits between them — drag to resize, double-click
/// to reset to `defaultLeft`, and hover shows the resize cursor.
public struct SCResizable<Left: View, Right: View>: View {
    @Binding private var leftWidth: CGFloat
    private let minLeft: CGFloat
    private let maxLeft: CGFloat
    private let defaultLeft: CGFloat
    private let left: Left
    private let right: Right

    public init(
        leftWidth: Binding<CGFloat>,
        minLeft: CGFloat = 180,
        maxLeft: CGFloat = 520,
        defaultLeft: CGFloat = 260,
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) {
        _leftWidth = leftWidth
        self.minLeft = minLeft
        self.maxLeft = maxLeft
        self.defaultLeft = defaultLeft
        self.left = left()
        self.right = right()
    }

    public var body: some View {
        GeometryReader { proxy in
            let total = proxy.size.width
            let clampedLeft = min(max(leftWidth, minLeft), min(maxLeft, max(minLeft, total - minLeft)))

            HStack(spacing: 0) {
                left
                    .frame(width: clampedLeft)
                    .frame(maxHeight: .infinity)

                divider

                right
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var divider: some View {
        ZStack {
            // Hit area
            Rectangle()
                .fill(Color.clear)
                .frame(width: 6)
                .contentShape(Rectangle())

            // Center hairline
            Rectangle()
                .fill(Theme.border)
                .frame(width: 1)
        }
        .frame(width: 6)
        .frame(maxHeight: .infinity)
        .onHover { inside in
            if inside {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let proposed = leftWidth + value.translation.width
                    leftWidth = min(max(proposed, minLeft), maxLeft)
                }
        )
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut) {
                leftWidth = defaultLeft
            }
        }
    }
}

#Preview("SCResizable — light") {
    struct PreviewHost: View {
        @State private var width: CGFloat = 260
        var body: some View {
            SCResizable(leftWidth: $width) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Sidebar")
                        .textStyle(.heading)
                        .foregroundStyle(Theme.foregroundPrimary)
                    Text("Drag the divider to resize.")
                        .textStyle(.caption)
                        .foregroundStyle(Theme.foregroundSecondary)
                    Text("Double-click to reset.")
                        .textStyle(.caption)
                        .foregroundStyle(Theme.foregroundTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Spacing.md)
                .background(Theme.surface)
            } right: {
                VStack {
                    Text("Content")
                        .textStyle(.heading)
                        .foregroundStyle(Theme.foregroundPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.surfaceRaised)
            }
            .frame(width: 720, height: 360)
            .background(Theme.background)
        }
    }
    return PreviewHost()
}

#Preview("SCResizable — dark") {
    struct PreviewHost: View {
        @State private var width: CGFloat = 300
        var body: some View {
            SCResizable(leftWidth: $width, minLeft: 160, maxLeft: 480, defaultLeft: 240) {
                VStack {
                    Text("Left pane")
                        .textStyle(.body)
                        .foregroundStyle(Theme.foregroundPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.surface)
            } right: {
                VStack {
                    Text("Right pane")
                        .textStyle(.body)
                        .foregroundStyle(Theme.foregroundPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.surfaceRaised)
            }
            .frame(width: 720, height: 360)
            .background(Theme.background)
            .preferredColorScheme(.dark)
        }
    }
    return PreviewHost()
}
