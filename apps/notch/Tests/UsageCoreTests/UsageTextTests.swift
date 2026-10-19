import Foundation
import Testing
@testable import UsageCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)

@Suite struct UsageTextTests {
    /// What a live read prints for these windows, row by row.
    private func liveRows(_ windows: [UsageWindow]) -> [String] {
        let width = windows.map(\.label.count).max() ?? 0
        return windows.map { "     " + UsageText.row($0, labelWidth: width, now: now, colour: false) }
    }

    private let windows = [
        UsageWindow(label: "5-hour", percentUsed: 37, resetsAt: now.addingTimeInterval(2 * 3600 + 10 * 60)),
        UsageWindow(label: "Weekly · all models", percentUsed: 62, resetsAt: now.addingTimeInterval(3 * 86400)),
        UsageWindow(label: "Weekly · Opus", percentUsed: 100, resetsAt: nil),
    ]

    @Test func cachedPrintsTheSameRowsAsALiveRead() throws {
        // Through the file and back, as --cached reads it.
        let snapshot = SharedSnapshot(updatedAt: now, copies: [
            .init(letter: "A", label: "Claude A", color: "#2F7BF5", plan: "Max 20x", inFront: true, state: .ok, readAt: now,
                  windows: windows.map(SharedSnapshot.Window.init)),
        ])
        let read = try #require(SharedSnapshot.decode(try snapshot.encoded()))
        let lines = UsageText.cached(read.copies, now: now, colour: false).split(separator: "\n").map(String.init)
        #expect(lines.first == "Claude A  ·  in front")
        #expect(lines[1] == "   Max 20x")
        #expect(Array(lines.dropFirst(2)) == liveRows(windows))
        #expect(lines[2].hasPrefix("     5-hour               ████░░░░░░   37%  resets in 2h 10m ("))
    }

    @Test func aCopyWithoutNewNumbersSaysWhyAndHowOld() {
        let copies: [SharedSnapshot.Copy] = [
            .init(letter: "B", label: "Work", color: "#E5484D", plan: "Team", inFront: false, state: .stale,
                  readAt: now.addingTimeInterval(-40 * 60), windows: [.init(windows[0])]),
            .init(letter: "C", label: "Claude C", color: "#30A46C", plan: nil, inFront: false, state: .signedOut, readAt: nil, windows: []),
        ]
        #expect(UsageText.cached(copies, now: now, colour: false) == """
        Work
           Team
             Login no longer valid; open this Claude to renew it  (numbers from 40m ago)
        \(liveRows([windows[0]])[0])

        Claude C
             Not signed in
        """)
    }

    @Test func coloursOnlyWhenAsked() {
        let copy = SharedSnapshot.Copy(letter: "A", label: "Claude A", color: "#2F7BF5", plan: nil, inFront: false, state: .ok, readAt: now, windows: [])
        #expect(UsageText.cached([copy], now: now, colour: true) == "\u{1B}[1;38;2;47;123;245mClaude A\u{1B}[0m")
        #expect(UsageText.foreground("not a colour") == "39")
    }
}
