import SwiftUI

/// Renders the chat transcript in either bubble or timeline mode, collapsing
/// runs of 2+ consecutive tool calls into a single `ToolGroupView`.
///
/// This is the view `ChatDetailView` uses; it reads the persisted
/// `MessageStyle` from `@AppStorage` and dispatches to the appropriate inner
/// renderer. Callers still pass approve/deny handlers.
public struct ChatTranscriptView: View {
    public let messages: [ChatBubble]
    public var onApproveToolCall: ((String) -> Void)?
    public var onDenyToolCall: ((String) -> Void)?

    @AppStorage(MessageStyle.storageKey) private var style: MessageStyle = .bubbles

    public init(
        messages: [ChatBubble],
        onApproveToolCall: ((String) -> Void)? = nil,
        onDenyToolCall: ((String) -> Void)? = nil
    ) {
        self.messages = messages
        self.onApproveToolCall = onApproveToolCall
        self.onDenyToolCall = onDenyToolCall
    }

    public var body: some View {
        switch style {
        case .bubbles:
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(runs) { run in
                    renderRun(run)
                        .id(run.id)
                }
            }
        case .timeline:
            TimelineMessageListView(
                messages: messages,
                onApproveToolCall: onApproveToolCall,
                onDenyToolCall: onDenyToolCall
            )
        }
    }

    // MARK: - Run grouping

    /// Partitions `messages` into "runs": a single message OR a contiguous
    /// group of 2+ tool-call / tool-result bubbles. Runs are rendered via
    /// `ToolGroupView` when they contain multiple tool items, otherwise the
    /// single message renders as-is.
    private var runs: [TranscriptRun] {
        var out: [TranscriptRun] = []
        var buffer: [ChatBubble] = []

        func flush() {
            guard !buffer.isEmpty else { return }
            if buffer.count >= 2 {
                out.append(.toolGroup(buffer))
            } else if let only = buffer.first {
                out.append(.single(only))
            }
            buffer.removeAll()
        }

        for bubble in messages {
            if bubble.isGroupableTool {
                buffer.append(bubble)
            } else {
                flush()
                out.append(.single(bubble))
            }
        }
        flush()
        return out
    }

    @ViewBuilder
    private func renderRun(_ run: TranscriptRun) -> some View {
        switch run {
        case let .single(bubble):
            ChatBubbleView(
                bubble: bubble,
                onApproveToolCall: onApproveToolCall,
                onDenyToolCall: onDenyToolCall
            )
        case let .toolGroup(bubbles):
            ToolGroupView(items: bubbles.compactMap { $0.toolGroupItem })
        }
    }
}

// MARK: - Run model

private enum TranscriptRun: Identifiable {
    case single(ChatBubble)
    case toolGroup([ChatBubble])

    var id: String {
        switch self {
        case let .single(bubble): return "b-\(bubble.id.uuidString)"
        case let .toolGroup(bubbles):
            let first = bubbles.first?.id.uuidString ?? "empty"
            return "g-\(first)-\(bubbles.count)"
        }
    }
}

// MARK: - ChatBubble adapters

private extension ChatBubble {
    /// Whether this bubble should fold into a tool group when it sits in a
    /// contiguous run of siblings. Pending approval stays standalone — urgent
    /// user decision shouldn't be buried inside a collapse.
    var isGroupableTool: Bool {
        switch kind {
        case .toolCall, .toolResult, .toolCallDenied: return true
        case .toolCallPending: return false
        default: return false
        }
    }

    /// Projects this bubble into a `ToolGroupView.Item` when it represents a
    /// tool call, call-result, or denial. Returns nil for non-tool bubbles.
    var toolGroupItem: ToolGroupView.Item? {
        switch kind {
        case let .toolCall(name, callId):
            return .init(id: callId, toolName: name, state: .running, output: nil)
        case let .toolResult(content, isError, callId):
            let state: ToolGroupView.Item.State = isError ? .error(message: nil) : .done
            // Tool calls carry the real name; on the result bubble we only
            // have callId, so use callId as the name fallback. Good-enough
            // until the view model threads names through.
            return .init(id: callId, toolName: "tool", state: state, output: content)
        case let .toolCallDenied(name, callId):
            return .init(id: callId, toolName: name, state: .denied, output: nil)
        default:
            return nil
        }
    }
}
