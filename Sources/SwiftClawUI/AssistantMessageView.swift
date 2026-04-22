import AppKit
import SwiftUI

public struct AssistantMessageView: View {
    public let text: String
    @State private var isHovered = false
    @State private var copied = false

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("AI")
                .font(Theme.monoFont)
                .fontWeight(.bold)
                .foregroundStyle(Theme.secondaryForeground)
                .padding(.top, 3)

            MarkdownContentView(text: text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    if isHovered {
                        SCButton(icon: copied ? "checkmark" : "doc.on.doc", size: .small) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                            copied = true
                            Task {
                                try? await Task.sleep(nanoseconds: 1_600_000_000)
                                copied = false
                            }
                        }
                        .help(copied ? "Copied" : "Copy message")
                        .transition(.opacity)
                    }
                }

            Spacer(minLength: Theme.bubbleMinSpacing)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}
