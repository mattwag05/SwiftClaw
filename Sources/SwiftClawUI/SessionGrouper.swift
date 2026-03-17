import Foundation
import SwiftClawCore

/// A time-bucketed group of sessions for display in the sidebar.
public struct SessionGroup: Identifiable, Sendable {
    public let id: String        // "today", "yesterday", "last7", "last30", "2026-01"
    public let title: String     // "Today", "Yesterday", "Last 7 Days", "January 2026"
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

/// Groups a flat list of sessions into time buckets.
public enum SessionGrouper {

    public static func group(_ sessions: [SessionSummary]) -> [SessionGroup] {
        guard !sessions.isEmpty else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
              let startOf7Days     = calendar.date(byAdding: .day, value: -7, to: startOfToday),
              let startOf30Days    = calendar.date(byAdding: .day, value: -30, to: startOfToday)
        else { return [] }

        var today:     [SessionSummary] = []
        var yesterday: [SessionSummary] = []
        var last7:     [SessionSummary] = []
        var last30:    [SessionSummary] = []
        var monthly:   [String: [SessionSummary]] = [:]
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
                monthly[key]!.append(session)
            }
        }

        var groups: [SessionGroup] = []

        if !today.isEmpty {
            groups.append(SessionGroup(id: "today", title: "Today", sessions: today))
        }
        if !yesterday.isEmpty {
            groups.append(SessionGroup(id: "yesterday", title: "Yesterday", sessions: yesterday))
        }
        if !last7.isEmpty {
            groups.append(SessionGroup(id: "last7", title: "Last 7 Days", sessions: last7))
        }
        if !last30.isEmpty {
            groups.append(SessionGroup(id: "last30", title: "Last 30 Days", sessions: last30))
        }
        for key in monthOrder {
            if let sessions = monthly[key], !sessions.isEmpty {
                groups.append(SessionGroup(id: key, title: monthTitle(for: key), sessions: sessions))
            }
        }

        return groups
    }

    // MARK: - Helpers

    private static func monthKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year  = components.year  ?? 2000
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
