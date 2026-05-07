import SwiftUI

/// Collapsible card representing a tool call, pending approval, denial, or result.
public struct GemmaToolCallCard: View {
    public let kind: ChatBubble.Kind
    public var onApprove: ((String) -> Void)?
    public var onDeny: ((String) -> Void)?

    @State private var expanded = false

    public init(
        kind: ChatBubble.Kind,
        onApprove: ((String) -> Void)? = nil,
        onDeny: ((String) -> Void)? = nil
    ) {
        self.kind = kind
        self.onApprove = onApprove
        self.onDeny = onDeny
    }

    public var body: some View {
        switch kind {
        case let .toolCall(name, callId):
            collapsedRow(
                icon: icon(for: name),
                verb: "Running",
                target: name,
                accent: GemmaAccent.emerald,
                spinning: true,
                callId: callId
            )

        case let .toolCallPending(name, arguments, callId):
            VStack(alignment: .leading, spacing: 6) {
                collapsedRow(
                    icon: icon(for: name),
                    verb: "Awaiting approval",
                    target: name,
                    accent: Theme.warning,
                    spinning: false,
                    callId: callId
                )
                if expanded {
                    Text(arguments)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GemmaForeground.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Surface.s04)
                        .clipShape(RoundedRectangle(cornerRadius: GemmaRadius.sm))
                }
                HStack(spacing: 8) {
                    Button("Allow") { onApprove?(callId) }
                        .buttonStyle(GemmaActionButtonStyle(color: GemmaAccent.emerald))
                    Button("Deny") { onDeny?(callId) }
                        .buttonStyle(GemmaActionButtonStyle(color: GemmaAccent.error))
                }
                .padding(.leading, 4)
            }

        case let .toolCallDenied(name, _):
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(GemmaForeground.tertiary)
                Text(name)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(GemmaForeground.tertiary)
                Text("denied")
                    .font(.caption2)
                    .foregroundStyle(GemmaForeground.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Surface.s04)
            .clipShape(RoundedRectangle(cornerRadius: GemmaRadius.sm))

        case let .toolResult(content, isError, _):
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.gemmaQuick) { expanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isError ? "exclamationmark.circle" : "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(isError ? GemmaAccent.error : GemmaAccent.emerald)
                        Text(isError ? "Error" : "Result")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(GemmaForeground.secondary)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(GemmaForeground.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                if expanded {
                    Text(content)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GemmaForeground.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(isError ? GemmaAccent.errorFill : Surface.s04)
            .clipShape(RoundedRectangle(cornerRadius: GemmaRadius.sm))

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func collapsedRow(
        icon: String,
        verb: String,
        target: String,
        accent: Color,
        spinning: Bool,
        callId: String
    ) -> some View {
        Button {
            withAnimation(.gemmaQuick) { expanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accent)
                Text(verb)
                    .font(.caption2)
                    .foregroundStyle(GemmaForeground.tertiary)
                Text(target)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(GemmaForeground.secondary)
                Spacer()
                if spinning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Surface.s04)
        .clipShape(RoundedRectangle(cornerRadius: GemmaRadius.sm))
    }

    private func icon(for toolName: String) -> String {
        switch toolName {
        case "write_file", "edit_file", "delete_file": return "pencil"
        case "read_file", "list_files": return "doc.text"
        case "run_bash": return "terminal"
        case "web_search": return "magnifyingglass"
        case "fetch_url": return "arrow.up.right"
        case "calc": return "function"
        case "open_preview": return "eye"
        default:
            if toolName.hasPrefix("memory_") { return "brain" }
            return "bolt"
        }
    }
}

// MARK: - Action button style

private struct GemmaActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(configuration.isPressed ? 0.2 : 0.12))
            .clipShape(RoundedRectangle(cornerRadius: GemmaRadius.sm))
    }
}
