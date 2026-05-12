import AppKit
import SwiftUI

/// Small popover anchored to the composer's `@` chip. Inserts a useful
/// real-world snippet rather than a placeholder token — the AI doesn't
/// understand `@activeWindow`, but it does understand "Notes — Untitled
/// (focused window)" prefixed onto the prompt.
public struct MentionPopoverView: View {
    public let onSelect: (String) -> Void

    public init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Insert context")
            row(icon: "macwindow", title: "Active window") {
                onSelect(activeWindowDescription())
            }
            row(icon: "doc.on.clipboard", title: "Clipboard text") {
                onSelect(clipboardSnippet())
            }
            row(icon: "calendar", title: "Today's date") {
                onSelect(todaysDateSentence())
            }
            row(icon: "clock", title: "Current time") {
                onSelect(currentTimeSentence())
            }
            Divider().padding(.vertical, 4)
            sectionHeader("Tips")
            Text("Tip: drop a path with the paperclip → Choose file… to reference a file in this prompt.")
                .font(.system(size: 10.5))
                .foregroundStyle(GemmaForeground.tertiary)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .frame(width: 280)
    }

    // MARK: - Snippet builders

    private func activeWindowDescription() -> String {
        // The frontmost app might be SwiftClaw itself when this popover fires.
        // Skip past it to find the window the user actually cares about.
        let workspace = NSWorkspace.shared
        let myBundle = Bundle.main.bundleIdentifier
        let candidates = workspace.runningApplications.filter { app in
            app.activationPolicy == .regular &&
                !app.isHidden &&
                app.bundleIdentifier != myBundle
        }
        let frontApp = candidates.first(where: { $0.isActive }) ?? candidates.first
        let appName = frontApp?.localizedName ?? "the active app"
        return "Context: I'm currently looking at \(appName)."
    }

    private func clipboardSnippet() -> String {
        let pb = NSPasteboard.general
        let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return "(clipboard is empty)" }
        return "From my clipboard:\n```\n\(text)\n```"
    }

    private func todaysDateSentence() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return "Context: today is \(formatter.string(from: Date()))."
    }

    private func currentTimeSentence() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "Context: it's \(formatter.string(from: Date())) right now."
    }

    // MARK: - Layout helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(GemmaForeground.tertiary)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }

    private func row(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 11.5))
                    .foregroundStyle(GemmaForeground.secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(GemmaForeground.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
