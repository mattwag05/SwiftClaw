import SwiftUI
import SwiftClawCore

public struct SessionListView: View {
    public let sessions: [SessionSummary]
    @Binding public var selectedId: String?
    public let onDelete: (String) -> Void

    public init(
        sessions: [SessionSummary],
        selectedId: Binding<String?>,
        onDelete: @escaping (String) -> Void
    ) {
        self.sessions = sessions
        self._selectedId = selectedId
        self.onDelete = onDelete
    }

    public var body: some View {
        List(selection: $selectedId) {
            ForEach(sessions) { summary in
                SessionRowView(summary: summary)
                    .tag(summary.sessionId)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            onDelete(summary.sessionId)
                        }
                    }
            }
            .onDelete { offsets in
                let ids = offsets.map { sessions[$0].sessionId }
                ids.forEach { onDelete($0) }
            }
        }
    }
}
