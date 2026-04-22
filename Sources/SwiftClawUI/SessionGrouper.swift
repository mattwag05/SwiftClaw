import Foundation
import SwiftClawCore

/// A group of sessions rendered as a section header in the sidebar.
public struct SessionGroup: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let sessions: [SessionSummary]

    public var subtitle: String {
        "\(sessions.count) chat\(sessions.count == 1 ? "" : "s")"
    }

    public init(id: String, title: String, sessions: [SessionSummary]) {
        self.id = id
        self.title = title
        self.sessions = sessions
    }
}

/// How the session list groups its rows.
public enum GroupingMode: Sendable {
    /// Time buckets: Today / Yesterday / Last 7 / Last 30 / month buckets.
    /// Pinned sessions get their own group at the top.
    case time
    /// One group per folder, plus an `Unfiled` group for sessions with no
    /// folder. Pinned sessions still get a top group.
    case byFolder
}

public enum SessionGrouper {
    public static func group(
        _ sessions: [SessionSummary],
        mode: GroupingMode = .time,
        folders: [Folder] = []
    ) -> [SessionGroup] {
        guard !sessions.isEmpty else { return [] }

        let (pinned, rest) = partitionPinned(sessions)

        var groups: [SessionGroup] = []
        if !pinned.isEmpty {
            groups.append(SessionGroup(id: "pinned", title: "Pinned", sessions: pinned))
        }

        switch mode {
        case .time:
            groups.append(contentsOf: timeBuckets(rest))
        case .byFolder:
            groups.append(contentsOf: folderBuckets(rest, folders: folders))
        }

        return groups
    }

    private static func partitionPinned(
        _ sessions: [SessionSummary]
    ) -> (pinned: [SessionSummary], rest: [SessionSummary]) {
        var pinned: [SessionSummary] = []
        var rest: [SessionSummary] = []
        for session in sessions {
            if session.isPinned {
                pinned.append(session)
            } else {
                rest.append(session)
            }
        }
        pinned.sort { lhs, rhs in
            let l = lhs.pinnedAt ?? lhs.updatedAt
            let r = rhs.pinnedAt ?? rhs.updatedAt
            return l > r
        }
        return (pinned, rest)
    }

    // MARK: - Time buckets

    private static func timeBuckets(_ sessions: [SessionSummary]) -> [SessionGroup] {
        guard !sessions.isEmpty else { return [] }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
              let startOf7Days = calendar.date(byAdding: .day, value: -7, to: startOfToday),
              let startOf30Days = calendar.date(byAdding: .day, value: -30, to: startOfToday)
        else { return [] }

        var today: [SessionSummary] = []
        var yesterday: [SessionSummary] = []
        var last7: [SessionSummary] = []
        var last30: [SessionSummary] = []
        var monthly: [String: [SessionSummary]] = [:]
        var monthOrder: [String] = []

        for session in sessions {
            let date = session.updatedAt
            if date >= startOfToday {
                today.append(session)
            } else if date >= startOfYesterday {
                yesterday.append(session)
            } else if date >= startOf7Days {
                last7.append(session)
            } else if date >= startOf30Days {
                last30.append(session)
            } else {
                let key = monthKey(for: date, calendar: calendar)
                if monthly[key] == nil {
                    monthly[key] = []
                    monthOrder.append(key)
                }
                monthly[key]?.append(session)
            }
        }

        var groups: [SessionGroup] = []
        if !today.isEmpty { groups.append(SessionGroup(id: "today", title: "Today", sessions: today)) }
        if !yesterday.isEmpty { groups.append(SessionGroup(id: "yesterday", title: "Yesterday", sessions: yesterday)) }
        if !last7.isEmpty { groups.append(SessionGroup(id: "last7", title: "Last 7 Days", sessions: last7)) }
        if !last30.isEmpty { groups.append(SessionGroup(id: "last30", title: "Last 30 Days", sessions: last30)) }
        for key in monthOrder {
            if let sessions = monthly[key], !sessions.isEmpty {
                groups.append(SessionGroup(id: key, title: monthTitle(for: key), sessions: sessions))
            }
        }
        return groups
    }

    // MARK: - Folder buckets

    private static func folderBuckets(
        _ sessions: [SessionSummary],
        folders: [Folder]
    ) -> [SessionGroup] {
        var byFolder: [UUID: [SessionSummary]] = [:]
        var unfiled: [SessionSummary] = []

        for session in sessions {
            if let id = session.folderID {
                byFolder[id, default: []].append(session)
            } else {
                unfiled.append(session)
            }
        }

        let sortedFolders = folders.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.createdAt < rhs.createdAt
        }

        var groups: [SessionGroup] = []
        for folder in sortedFolders {
            let items = (byFolder[folder.id] ?? []).sorted { $0.updatedAt > $1.updatedAt }
            if !items.isEmpty {
                groups.append(SessionGroup(id: "folder-\(folder.id.uuidString)",
                                           title: folder.name,
                                           sessions: items))
            }
        }
        if !unfiled.isEmpty {
            let items = unfiled.sorted { $0.updatedAt > $1.updatedAt }
            groups.append(SessionGroup(id: "unfiled", title: "Unfiled", sessions: items))
        }
        return groups
    }

    // MARK: - Helpers

    private static func monthKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 2000
        let month = components.month ?? 1
        return String(format: "%04d-%02d", year, month)
    }

    private static func monthTitle(for key: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: key) else { return key }
        let display = DateFormatter()
        display.dateFormat = "MMMM yyyy"
        return display.string(from: date)
    }
}
