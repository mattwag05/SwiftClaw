import AppKit
import SwiftUI

/// Popover anchored to the composer's paperclip chip. Lets the user pick
/// recent clipboard items, screenshots, or files to attach as context.
///
/// The "real" attachment plumbing isn't shipped yet — for now this exposes:
///   • The most recent string on the clipboard (one click → inserted as a
///     fenced code block).
///   • A "Choose file…" button that opens NSOpenPanel and inserts the
///     selected path as `@/path/to/file`.
///   • Placeholder rows for screenshots and active-window grab so the user
///     sees what's coming.
public struct AttachPopoverView: View {
    public let onInsertText: (String) -> Void
    public let onAttachFile: (URL) -> Void

    @State private var clipboardPreview: String = ""

    public init(
        onInsertText: @escaping (String) -> Void,
        onAttachFile: @escaping (URL) -> Void = { _ in }
    ) {
        self.onInsertText = onInsertText
        self.onAttachFile = onAttachFile
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Recent")
            clipboardRow
            comingSoon(icon: "camera.viewfinder", title: "Screenshot", subtitle: "⇧⌘5 to capture")
            comingSoon(icon: "macwindow", title: "Active window", subtitle: "Capture focused app")
            Divider().padding(.vertical, 4)
            sectionHeader("From disk")
            chooseFileRow
        }
        .padding(.vertical, 8)
        .frame(width: 280)
        .onAppear { refreshClipboard() }
    }

    // MARK: - Rows

    private var clipboardRow: some View {
        Group {
            if clipboardPreview.isEmpty {
                row(
                    icon: "doc.on.clipboard",
                    title: "Clipboard",
                    subtitle: "Empty",
                    enabled: false
                ) {}
            } else {
                row(
                    icon: "doc.on.clipboard",
                    title: "Clipboard",
                    subtitle: clipboardPreview.prefix(64) + (clipboardPreview.count > 64 ? "…" : "")
                ) {
                    let lang = clipboardPreview.contains("\n") ? "" : ""
                    let snippet = "```\(lang)\n\(clipboardPreview)\n```"
                    onInsertText(snippet)
                }
            }
        }
    }

    private var chooseFileRow: some View {
        row(
            icon: "doc.badge.plus",
            title: "Choose file…",
            subtitle: "Reference a path in this prompt"
        ) {
            chooseFile()
        }
    }

    // MARK: - Helpers

    private func row<S: StringProtocol>(
        icon: String,
        title: String,
        subtitle: S,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(GemmaForeground.secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(GemmaForeground.primary)
                    Text(String(subtitle))
                        .font(.system(size: 10.5))
                        .foregroundStyle(GemmaForeground.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func comingSoon(icon: String, title: String, subtitle: String) -> some View {
        row(icon: icon, title: title, subtitle: "\(subtitle) — coming soon", enabled: false) {}
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(GemmaForeground.tertiary)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }

    private func refreshClipboard() {
        let pb = NSPasteboard.general
        clipboardPreview = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            onAttachFile(url)
            onInsertText("@\(url.path)")
        }
    }
}
