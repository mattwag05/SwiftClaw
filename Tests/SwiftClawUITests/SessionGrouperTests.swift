import Foundation
import SwiftClawCore
@testable import SwiftClawUI
import Testing

// MARK: - Fixtures

private func summary(
    id: String = UUID().uuidString,
    updatedAt: Date,
    title: String? = nil,
    isPinned: Bool = false,
    pinnedAt: Date? = nil,
    folderID: UUID? = nil
) -> SessionSummary {
    SessionSummary(
        sessionId: id,
        agentName: "Agent",
        messageCount: 1,
        updatedAt: updatedAt,
        preview: "preview",
        title: title,
        isPinned: isPinned,
        pinnedAt: pinnedAt,
        folderID: folderID,
        tags: []
    )
}

private func makeFolder(
    id: UUID = UUID(),
    name: String,
    order: Int = 0,
    createdAt: Date = Date(timeIntervalSinceReferenceDate: 0)
) -> Folder {
    Folder(id: id, name: name, order: order, createdAt: createdAt)
}

/// Return a date on the calendar day `n` days before today, anchored at
/// local noon so the result lands safely inside that day's bucket and
/// not on a start-of-day boundary (even around DST transitions, where
/// simple `Date() - n*24h` could drift into the adjacent bucket).
private func daysAgo(_ n: Int) -> Date {
    let calendar = Calendar.current
    let targetDay = calendar.date(byAdding: .day, value: -n, to: Date())!
    let parts = calendar.dateComponents([.year, .month, .day], from: targetDay)
    return calendar.date(from: DateComponents(
        year: parts.year,
        month: parts.month,
        day: parts.day,
        hour: 12,
        minute: 0,
        second: 0
    ))!
}

// MARK: - SessionGroup

@Suite("SessionGroup subtitle")
struct SessionGroupSubtitleTests {
    @Test("Singular form for one session")
    func singular() {
        let g = SessionGroup(id: "x", title: "Today", sessions: [summary(updatedAt: Date())])
        #expect(g.subtitle == "1 chat")
    }

    @Test("Plural form for multiple sessions")
    func plural() {
        let g = SessionGroup(id: "x", title: "Today", sessions: [
            summary(updatedAt: Date()),
            summary(updatedAt: Date()),
            summary(updatedAt: Date()),
        ])
        #expect(g.subtitle == "3 chats")
    }

    @Test("Plural form for zero sessions")
    func zeroIsPlural() {
        let g = SessionGroup(id: "x", title: "Today", sessions: [])
        #expect(g.subtitle == "0 chats")
    }
}

// MARK: - Time mode

@Suite("SessionGrouper time mode")
struct SessionGrouperTimeTests {
    @Test("Empty input returns no groups")
    func emptyReturnsEmpty() {
        #expect(SessionGrouper.group([]).isEmpty)
        #expect(SessionGrouper.group([], mode: .time).isEmpty)
    }

    @Test("A session with updatedAt = now lands in the Today bucket")
    func todayBucket() {
        let s = summary(updatedAt: Date())
        let groups = SessionGrouper.group([s])
        #expect(groups.count == 1)
        #expect(groups[0].id == "today")
        #expect(groups[0].title == "Today")
        #expect(groups[0].sessions.map { $0.sessionId } == [s.sessionId])
    }

    @Test("A session 1 day back lands in the Yesterday bucket")
    func yesterdayBucket() {
        let s = summary(updatedAt: daysAgo(1))
        let groups = SessionGrouper.group([s])
        #expect(groups.count == 1)
        #expect(groups[0].id == "yesterday")
        #expect(groups[0].title == "Yesterday")
    }

    @Test("A session 3 days back lands in the Last 7 Days bucket")
    func last7Bucket() {
        let s = summary(updatedAt: daysAgo(3))
        let groups = SessionGrouper.group([s])
        #expect(groups.count == 1)
        #expect(groups[0].id == "last7")
        #expect(groups[0].title == "Last 7 Days")
    }

    @Test("A session 15 days back lands in the Last 30 Days bucket")
    func last30Bucket() {
        let s = summary(updatedAt: daysAgo(15))
        let groups = SessionGrouper.group([s])
        #expect(groups.count == 1)
        #expect(groups[0].id == "last30")
        #expect(groups[0].title == "Last 30 Days")
    }

    @Test("A session 90 days back falls into a month bucket with a formatted title")
    func monthlyBucket() {
        let d = daysAgo(90)
        let s = summary(updatedAt: d)
        let groups = SessionGrouper.group([s])
        #expect(groups.count == 1)

        // The bucket id is "YYYY-MM" for the session's calendar month.
        let comps = Calendar.current.dateComponents([.year, .month], from: d)
        let expectedID = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        #expect(groups[0].id == expectedID)

        // The title is the localized "MMMM yyyy" — we don't lock to a specific
        // string (tests should survive locale variation), but it must contain
        // the 4-digit year.
        #expect(groups[0].title.contains(String(format: "%04d", comps.year ?? 0)))
    }

    @Test("Multiple months produce multiple month buckets, in insertion order")
    func multipleMonths() {
        // 60 and 120 days back are guaranteed to fall in different months.
        let a = summary(updatedAt: daysAgo(60))
        let b = summary(updatedAt: daysAgo(120))
        // Insert older first so we can verify the function preserves
        // the order sessions are encountered in.
        let groups = SessionGrouper.group([b, a])
        #expect(groups.count == 2)
        let ids = groups.map { $0.id }
        let compsA = Calendar.current.dateComponents([.year, .month], from: a.updatedAt)
        let compsB = Calendar.current.dateComponents([.year, .month], from: b.updatedAt)
        let idA = String(format: "%04d-%02d", compsA.year ?? 0, compsA.month ?? 0)
        let idB = String(format: "%04d-%02d", compsB.year ?? 0, compsB.month ?? 0)
        #expect(ids == [idB, idA])
    }

    @Test("Full bucket sweep produces groups in canonical order")
    func fullBucketOrdering() {
        let today = summary(updatedAt: Date())
        let yesterday = summary(updatedAt: daysAgo(1))
        let week = summary(updatedAt: daysAgo(3))
        let month = summary(updatedAt: daysAgo(15))
        let longAgo = summary(updatedAt: daysAgo(90))

        // Deliberately shuffled input — SessionGrouper is responsible for ordering.
        let groups = SessionGrouper.group([longAgo, week, today, month, yesterday])
        let ids = groups.map { $0.id }
        // The month bucket id is dynamic; check the prefix and then confirm
        // the last id is "YYYY-MM".
        #expect(ids.count == 5)
        #expect(Array(ids.prefix(4)) == ["today", "yesterday", "last7", "last30"])
        #expect(ids[4].range(of: #"^\d{4}-\d{2}$"#, options: .regularExpression) != nil)
    }
}

// MARK: - Pinning

@Suite("SessionGrouper pinning")
struct SessionGrouperPinningTests {
    @Test("A single pinned session produces a Pinned group and no time group")
    func onlyPinned() {
        let s = summary(updatedAt: Date(), isPinned: true)
        let groups = SessionGrouper.group([s])
        #expect(groups.count == 1)
        #expect(groups[0].id == "pinned")
        #expect(groups[0].title == "Pinned")
        #expect(groups[0].sessions.map { $0.sessionId } == [s.sessionId])
    }

    @Test("Pinned group is emitted before time buckets")
    func pinnedComesFirst() {
        let pinned = summary(updatedAt: Date(), isPinned: true)
        let unpinned = summary(updatedAt: Date())
        let groups = SessionGrouper.group([unpinned, pinned])
        #expect(groups.map { $0.id } == ["pinned", "today"])
    }

    @Test("Pinned sessions are excluded from the time buckets they would otherwise occupy")
    func pinnedExcludedFromTimeBuckets() {
        let pinned = summary(updatedAt: daysAgo(3), isPinned: true)
        let groups = SessionGrouper.group([pinned])
        // 3 days back would normally go to `last7`; with isPinned=true it
        // goes to pinned instead, and the last7 bucket never materializes.
        #expect(groups.count == 1)
        #expect(groups[0].id == "pinned")
    }

    @Test("Pinned sessions sort by pinnedAt descending when present")
    func pinnedSortByPinnedAt() {
        let early = Date(timeIntervalSinceReferenceDate: 1000)
        let middle = Date(timeIntervalSinceReferenceDate: 2000)
        let late = Date(timeIntervalSinceReferenceDate: 3000)

        let a = summary(id: "a", updatedAt: early, isPinned: true, pinnedAt: late)
        let b = summary(id: "b", updatedAt: late, isPinned: true, pinnedAt: early)
        let c = summary(id: "c", updatedAt: middle, isPinned: true, pinnedAt: middle)

        let groups = SessionGrouper.group([a, b, c])
        #expect(groups.count == 1)
        // pinnedAt descending: a (late) → c (middle) → b (early)
        #expect(groups[0].sessions.map { $0.sessionId } == ["a", "c", "b"])
    }

    @Test("Pinned sessions fall back to updatedAt when pinnedAt is nil")
    func pinnedFallbackToUpdatedAt() {
        let early = Date(timeIntervalSinceReferenceDate: 1000)
        let late = Date(timeIntervalSinceReferenceDate: 3000)

        let a = summary(id: "a", updatedAt: early, isPinned: true, pinnedAt: nil)
        let b = summary(id: "b", updatedAt: late, isPinned: true, pinnedAt: nil)

        let groups = SessionGrouper.group([a, b])
        #expect(groups[0].sessions.map { $0.sessionId } == ["b", "a"])
    }
}

// MARK: - Folder mode

@Suite("SessionGrouper folder mode")
struct SessionGrouperFolderTests {
    @Test("Empty input in folder mode returns no groups")
    func emptyReturnsEmpty() {
        #expect(SessionGrouper.group([], mode: .byFolder, folders: []).isEmpty)
        let f = makeFolder(name: "Projects")
        #expect(SessionGrouper.group([], mode: .byFolder, folders: [f]).isEmpty)
    }

    @Test("Sessions with no folderID produce an Unfiled group")
    func allUnfiled() {
        let s1 = summary(updatedAt: daysAgo(1))
        let s2 = summary(updatedAt: Date())
        let groups = SessionGrouper.group([s1, s2], mode: .byFolder, folders: [])
        #expect(groups.count == 1)
        #expect(groups[0].id == "unfiled")
        #expect(groups[0].title == "Unfiled")
        // Sorted updatedAt descending.
        #expect(groups[0].sessions.map { $0.sessionId } == [s2.sessionId, s1.sessionId])
    }

    @Test("Folders are emitted in declared order, then Unfiled at the end")
    func folderOrdering() {
        let fA = makeFolder(name: "Alpha", order: 0)
        let fB = makeFolder(name: "Bravo", order: 1)
        let sA = summary(updatedAt: Date(), folderID: fA.id)
        let sB = summary(updatedAt: Date(), folderID: fB.id)
        let sU = summary(updatedAt: Date())
        let groups = SessionGrouper.group([sU, sB, sA], mode: .byFolder, folders: [fB, fA])
        #expect(groups.map { $0.title } == ["Alpha", "Bravo", "Unfiled"])
    }

    @Test("Folder ordering ties are broken by createdAt ascending")
    func folderCreatedAtTiebreaker() {
        let older = Date(timeIntervalSinceReferenceDate: 1000)
        let newer = Date(timeIntervalSinceReferenceDate: 2000)
        let fOlder = makeFolder(name: "Older", order: 0, createdAt: older)
        let fNewer = makeFolder(name: "Newer", order: 0, createdAt: newer)
        let sNew = summary(updatedAt: Date(), folderID: fNewer.id)
        let sOld = summary(updatedAt: Date(), folderID: fOlder.id)
        let groups = SessionGrouper.group([sNew, sOld],
                                          mode: .byFolder,
                                          folders: [fNewer, fOlder])
        // Older folder (lower createdAt) wins the tie.
        #expect(groups.map { $0.title } == ["Older", "Newer"])
    }

    @Test("Sessions inside a folder are sorted by updatedAt descending")
    func intraFolderSort() {
        let f = makeFolder(name: "Projects")
        let earliest = summary(id: "earliest", updatedAt: daysAgo(3), folderID: f.id)
        let middle = summary(id: "middle", updatedAt: daysAgo(1), folderID: f.id)
        let latest = summary(id: "latest", updatedAt: Date(), folderID: f.id)
        let groups = SessionGrouper.group([earliest, latest, middle],
                                          mode: .byFolder,
                                          folders: [f])
        #expect(groups.count == 1)
        #expect(groups[0].sessions.map { $0.sessionId } == ["latest", "middle", "earliest"])
    }

    @Test("Empty folders are omitted from the output")
    func emptyFoldersOmitted() {
        let fEmpty = makeFolder(name: "Empty", order: 0)
        let fUsed = makeFolder(name: "Used", order: 1)
        let s = summary(updatedAt: Date(), folderID: fUsed.id)
        let groups = SessionGrouper.group([s], mode: .byFolder, folders: [fEmpty, fUsed])
        #expect(groups.map { $0.title } == ["Used"])
    }

    @Test("Sessions referencing an unknown folderID are silently dropped")
    func orphanSessionsDropped() {
        // This documents the current behavior. If a session's folderID no
        // longer exists in the folder list, it doesn't appear in any group
        // and does NOT fall back to Unfiled.
        let f = makeFolder(name: "Real", order: 0)
        let orphan = summary(id: "orphan", updatedAt: Date(), folderID: UUID())
        let kept = summary(id: "kept", updatedAt: Date(), folderID: f.id)
        let groups = SessionGrouper.group([orphan, kept],
                                          mode: .byFolder,
                                          folders: [f])
        #expect(groups.count == 1)
        #expect(groups[0].title == "Real")
        #expect(groups[0].sessions.map { $0.sessionId } == ["kept"])
    }

    @Test("Pinned group appears above folder groups")
    func pinnedAboveFolders() {
        let f = makeFolder(name: "Projects")
        let pinned = summary(id: "pin", updatedAt: Date(), isPinned: true, folderID: f.id)
        let regular = summary(id: "reg", updatedAt: Date(), folderID: f.id)
        let groups = SessionGrouper.group([pinned, regular],
                                          mode: .byFolder,
                                          folders: [f])
        #expect(groups.map { $0.id }.first == "pinned")
        // Pinned session is removed from its folder bucket.
        let projectsGroup = groups.first(where: { $0.title == "Projects" })
        #expect(projectsGroup?.sessions.map { $0.sessionId } == ["reg"])
    }

    @Test("Unfiled section is emitted last, after every folder")
    func unfiledAlwaysLast() {
        let fA = makeFolder(name: "Alpha", order: 0)
        let fB = makeFolder(name: "Bravo", order: 1)
        let sA = summary(updatedAt: Date(), folderID: fA.id)
        let sB = summary(updatedAt: Date(), folderID: fB.id)
        let sU = summary(updatedAt: Date())
        let groups = SessionGrouper.group([sU, sA, sB],
                                          mode: .byFolder,
                                          folders: [fA, fB])
        #expect(groups.map { $0.id }.last == "unfiled")
    }
}
