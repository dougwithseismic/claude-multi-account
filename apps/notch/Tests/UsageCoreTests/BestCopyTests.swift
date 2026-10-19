import Foundation
import Testing
@testable import UsageCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func copy(_ letter: String, fiveHour: Double?, weekly: [Double] = [], readAgo: TimeInterval = 60, resetsIn: TimeInterval = 3600) -> BestCopy.Candidate {
    var windows: [UsageWindow] = []
    if let fiveHour { windows.append(UsageWindow(label: "5-hour", percentUsed: fiveHour, resetsAt: now.addingTimeInterval(resetsIn))) }
    for (index, percent) in weekly.enumerated() {
        let label = index == 0 ? "Weekly · all models" : "Weekly · Fable"
        windows.append(UsageWindow(label: label, percentUsed: percent, resetsAt: now.addingTimeInterval(3 * 86400)))
    }
    return BestCopy.Candidate(letter: letter, report: UsageReport(windows: windows, extraUsage: nil), readAt: now.addingTimeInterval(-readAgo))
}

@Suite struct BestCopyTests {
    @Test func theLowestFullestWindowWins() {
        // A's fullest is its weekly 70, B's its 5-hour 50, C's its weekly Fable 60.
        let choice = BestCopy.choose([
            copy("A", fiveHour: 10, weekly: [70]), copy("B", fiveHour: 50, weekly: [20]), copy("C", fiveHour: 5, weekly: [30, 60]),
        ], now: now)
        #expect(choice == .copy("B"))
    }

    @Test func aCopyOutOfAnyWindowIsPassedOver() {
        let choice = BestCopy.choose([copy("A", fiveHour: 0, weekly: [40, 100]), copy("B", fiveHour: 80)], now: now)
        #expect(choice == .copy("B"))
    }

    @Test func numbersOlderThanFifteenMinutesDontCount() {
        let choice = BestCopy.choose([copy("A", fiveHour: 1, readAgo: 16 * 60), copy("B", fiveHour: 80, readAgo: 14 * 60)], now: now)
        #expect(choice == .copy("B"))
        let unread = BestCopy.Candidate(letter: "C", report: nil, readAt: nil)
        #expect(BestCopy.choose([unread, copy("D", fiveHour: 99)], now: now) == .copy("D"))
    }

    @Test func tiesGoToTheEarlierCopy() {
        #expect(BestCopy.choose([copy("A", fiveHour: 30), copy("B", fiveHour: 30)], now: now) == .copy("A"))
        #expect(BestCopy.choose([copy("B", fiveHour: 30), copy("A", fiveHour: 30)], now: now) == .copy("B"))
    }

    @Test func aPlanThatReportsNoWindowsIsPassedOver() {
        let empty = BestCopy.Candidate(letter: "A", report: UsageReport(windows: [], extraUsage: nil), readAt: now)
        #expect(BestCopy.choose([empty, copy("B", fiveHour: 90)], now: now) == .copy("B"))
    }

    @Test func aWindowWhoseResetHasPassedCountsAsEmpty() {
        let back = copy("A", fiveHour: 100, resetsIn: -120)
        #expect(BestCopy.fullest(back, now: now) == 0)
        #expect(BestCopy.choose([back, copy("B", fiveHour: 10)], now: now) == .copy("A"))
    }

    @Test func noRoomNamesTheCopyBackFirst() {
        let choice = BestCopy.choose([
            copy("A", fiveHour: 100, resetsIn: 2 * 3600), copy("B", fiveHour: 100, readAgo: 3600, resetsIn: 40 * 60),
            copy("C", fiveHour: 20, readAgo: 3600),
        ], now: now)
        // B's numbers are an hour old, but a window that was full stays full until it resets.
        #expect(choice == .noRoom(back: BestCopy.Back(letter: "B", at: now.addingTimeInterval(40 * 60))))
        #expect(BestCopy.choose([], now: now) == .noRoom(back: nil))
    }
}
