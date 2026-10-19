import Foundation
import Testing
@testable import UsageCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let epoch = Int(now.timeIntervalSince1970)

/// What Claude Code passes a status line command on stdin, trimmed; `limits` goes in as
/// its `rate_limits`.
private func input(_ limits: String?) -> Data {
    let rateLimits = limits.map { #", "rate_limits": \#($0)"# } ?? ""
    return Data("""
    {
      "hook_event_name": "Status",
      "session_id": "abc123",
      "cwd": "/Users/me/project",
      "model": { "id": "claude-opus-4-1", "display_name": "Opus" },
      "workspace": { "current_dir": "/Users/me/project", "project_dir": "/Users/me/project" },
      "version": "2.1.0",
      "cost": { "total_cost_usd": 0.01234, "total_duration_ms": 45000 }\(rateLimits)
    }
    """.utf8)
}

private func copy(
    _ letter: String, _ fiveHour: Double?, _ weekly: Double?, inFront: Bool = false, state: SharedSnapshot.State = .ok,
    readAgo: TimeInterval = 60, color: String = "#2F7BF5"
) -> SharedSnapshot.Copy {
    var windows: [SharedSnapshot.Window] = []
    if let fiveHour { windows.append(.init(label: "5-hour", percent: fiveHour, resetsAt: now.addingTimeInterval(3600))) }
    if let weekly { windows.append(.init(label: "Weekly · all models", percent: weekly, resetsAt: now.addingTimeInterval(3 * 86400))) }
    return .init(
        letter: letter, label: "Claude \(letter)", color: color, plan: "Max 20x", inFront: inFront, state: state,
        readAt: now.addingTimeInterval(-readAgo), windows: windows
    )
}

private func snapshot(_ copies: [SharedSnapshot.Copy], age: TimeInterval = 60) -> SharedSnapshot {
    SharedSnapshot(updatedAt: now.addingTimeInterval(-age), copies: copies)
}

private let three = snapshot([
    copy("A", 37, 62, inFront: true), copy("B", 92, 100, color: "#E5484D"), copy("C", 12, 30, color: "#30A46C"),
])

private func plain(
    _ snapshot: SharedSnapshot?, _ session: StatusLine.Session? = nil, only: Set<String>? = nil, columns: Int? = nil
) -> String {
    StatusLine.plain(StatusLine.render(snapshot: snapshot, session: session, only: only, now: now, columns: columns))
}

@Suite struct StatusLineInputTests {
    @Test func bothWindowsFromRateLimits() {
        let data = input("""
        { "five_hour": { "used_percentage": 41.2, "resets_at": \(epoch + 3600) },
          "seven_day": { "used_percentage": 63, "resets_at": \(epoch + 86400) } }
        """)
        #expect(StatusLine.session(from: data, now: now) == .init(fiveHour: 41.2, sevenDay: 63))
    }

    @Test func noRateLimitsMeansNoSessionNumbers() {
        // A plan without them, or before the session's first answer.
        #expect(StatusLine.session(from: input(nil), now: now) == nil)
        #expect(StatusLine.session(from: input("{}"), now: now) == nil)
        #expect(StatusLine.session(from: input("null"), now: now) == nil)
    }

    @Test func eitherWindowCanBeMissing() {
        let fiveHourOnly = input(#"{ "five_hour": { "used_percentage": 12, "resets_at": \#(epoch + 600) } }"#)
        #expect(StatusLine.session(from: fiveHourOnly, now: now) == .init(fiveHour: 12, sevenDay: nil))
        let weeklyOnly = input(#"{ "seven_day": { "used_percentage": 88, "resets_at": \#(epoch + 600) } }"#)
        #expect(StatusLine.session(from: weeklyOnly, now: now) == .init(fiveHour: nil, sevenDay: 88))
        // A window without its percentage counts as missing.
        let noPercent = input(#"{ "five_hour": { "resets_at": \#(epoch + 600) }, "seven_day": { "used_percentage": 5 } }"#)
        #expect(StatusLine.session(from: noPercent, now: now) == .init(fiveHour: nil, sevenDay: 5))
    }

    @Test func aWindowPastItsResetIsEmptyAgain() {
        let data = input("""
        { "five_hour": { "used_percentage": 100, "resets_at": \(epoch - 1) },
          "seven_day": { "used_percentage": 40, "resets_at": \(epoch + 86400) } }
        """)
        #expect(StatusLine.session(from: data, now: now) == .init(fiveHour: 0, sevenDay: 40))
    }

    @Test func anythingElseIsNoSessionNumbers() {
        for text in ["", " ", "\n", "{", "{nope", "[]", "42", "\"text\"", "null", #"{"rate_limits": []}"#, #"{"rate_limits": "x"}"#,
                     #"{"rate_limits": {"five_hour": {"used_percentage": true}}}"#] {
            #expect(StatusLine.session(from: Data(text.utf8), now: now) == nil, "\(text)")
        }
        // Not even UTF-8.
        #expect(StatusLine.session(from: Data([0xFF, 0xFE, 0x00]), now: now) == nil)
    }

    @Test func numbersAsStringsOrIntegersAreRead() {
        let data = Data(#"{"rate_limits": {"five_hour": {"used_percentage": "41"}, "seven_day": {"used_percentage": 7}}}"#.utf8)
        #expect(StatusLine.session(from: data, now: now) == .init(fiveHour: 41, sevenDay: 7))
    }
}

@Suite struct StatusLineTests {
    @Test func eachCopysLetterThenItsFiveHourAndWeeklyFigures() {
        #expect(plain(three) == "▸A 37·62  B 92·✕  C 12·30")
    }

    @Test func lettersAreInTheirColoursAndRedFromNinety() {
        let line = StatusLine.render(snapshot: three, session: nil, now: now)
        #expect(line.contains("\u{1B}[1;38;2;47;123;245mA\u{1B}[0m"))
        #expect(line.contains("\u{1B}[38;2;47;123;245m▸\u{1B}[0m"))
        #expect(line.contains("\u{1B}[1;38;2;229;72;77mB\u{1B}[0m"))
        #expect(line.contains("\u{1B}[38;2;255;69;58m92\u{1B}[0m"))
        #expect(line.contains("\u{1B}[1;38;2;255;69;58m✕\u{1B}[0m"))
        // Under 90, the terminal's own colour.
        #expect(line.contains("A\u{1B}[0m 37\u{1B}[2m·\u{1B}[0m62"))
        let justUnder = StatusLine.render(snapshot: snapshot([copy("A", 89.4, 10)]), session: nil, now: now)
        #expect(!justUnder.contains("255;69;58"))
        #expect(StatusLine.plain(justUnder) == "A 89·10")
    }

    @Test func usedUpIsACrossInEitherWindowAndNinetyNineIsTheMostOtherwise() {
        #expect(plain(snapshot([copy("A", 100, 40), copy("B", 99.7, 99.6)])) == "A ✕·40  B 99·99")
    }

    @Test func missingWindowsAreDashes() {
        #expect(plain(snapshot([copy("A", nil, 40), copy("B", 20, nil), copy("C", nil, nil)])) == "A –·40  B 20·–  C –")
    }

    @Test func aWindowPastItsResetReadsEmpty() {
        let past = SharedSnapshot.Copy(
            letter: "A", label: "Claude A", color: "#2F7BF5", plan: nil, inFront: false, state: .ok, readAt: now.addingTimeInterval(-60),
            windows: [.init(label: "5-hour", percent: 100, resetsAt: now.addingTimeInterval(-1))]
        )
        #expect(plain(snapshot([past])) == "A 0·–")
    }

    @Test func oldNumbersAreDimmed() {
        let line = StatusLine.render(snapshot: snapshot([copy("C", 12, 30, readAgo: 40 * 60), copy("D", 5, 5, state: .stale)]), session: nil, now: now)
        #expect(line.contains("\u{1B}[1;38;2;47;123;245;2mC\u{1B}[0m"))
        #expect(line.contains("\u{1B}[2m12\u{1B}[0m"))
        #expect(line.contains(";2mD\u{1B}[0m"))
    }

    @Test func onlyTheCopiesAsked() {
        #expect(plain(three, only: ["A", "C"]) == "▸A 37·62  C 12·30")
        #expect(plain(three, only: ["Z"]) == "")
    }

    @Test func theSessionLeads() {
        #expect(plain(three, .init(fiveHour: 41.2, sevenDay: 63)) == "Code 41·63  ▸A 37·62  B 92·✕  C 12·30")
        #expect(plain(three, .init(fiveHour: 95, sevenDay: nil)) == "Code 95·–  ▸A 37·62  B 92·✕  C 12·30")
        #expect(plain(nil, .init(fiveHour: 100, sevenDay: 20)) == "Code ✕·20  Claude Notch isn't running")
        let line = StatusLine.render(snapshot: nil, session: .init(fiveHour: 91, sevenDay: 100), now: now)
        #expect(line.hasPrefix("\u{1B}[1;38;2;217;119;87mCode\u{1B}[0m \u{1B}[38;2;255;69;58m91\u{1B}[0m"))
        #expect(line.contains("\u{1B}[1;38;2;255;69;58m✕"))
    }

    @Test func aSessionOnACopysClaudeCodeFolderIsNamedInItsColour() {
        let session = StatusLine.Session(fiveHour: 41, sevenDay: 63, letter: "B")
        #expect(plain(three, session) == "Code B 41·63  ▸A 37·62  B 92·✕  C 12·30")
        let line = StatusLine.render(snapshot: three, session: session, now: now)
        #expect(line.hasPrefix("\u{1B}[1;38;2;217;119;87mCode\u{1B}[0m \u{1B}[1;38;2;229;72;77mB\u{1B}[0m 41"))
        // A letter no copy has is still named, in the accent.
        let other = StatusLine.render(snapshot: three, session: .init(fiveHour: 1, sevenDay: 2, letter: "Q"), now: now)
        #expect(other.contains("\u{1B}[1;38;2;217;119;87mQ\u{1B}[0m"))
    }

    @Test func theLetterComesFromTheClaudeCodeFolder() {
        #expect(StatusLine.letter(configDir: "/Users/me/.claude-B") == "B")
        #expect(StatusLine.letter(configDir: "/Users/me/.claude-c/") == "C")
        #expect(StatusLine.letter(configDir: "~/.claude-D") == "D")
        #expect(StatusLine.letter(configDir: nil) == nil)
        #expect(StatusLine.letter(configDir: "") == nil)
        #expect(StatusLine.letter(configDir: "/Users/me/.claude") == nil)
        #expect(StatusLine.letter(configDir: "/Users/me/.claude-work") == nil)
        #expect(StatusLine.letter(configDir: "/Users/me/.claude-1") == nil)
        #expect(StatusLine.letter(configDir: "/Users/me/claude-B") == nil)
    }

    @Test func aMissingOrOldSnapshotIsADimHint() {
        #expect(StatusLine.render(snapshot: nil, session: nil, now: now) == "\u{1B}[2mClaude Notch isn't running\u{1B}[0m")
        #expect(StatusLine.render(snapshot: snapshot([copy("A", 1, 1)], age: 20 * 60), session: nil, now: now) == "\u{1B}[2musage 20m old\u{1B}[0m")
        // Fifteen minutes is still fresh.
        #expect(plain(snapshot([copy("A", 1, 1)], age: 15 * 60)) == "A 1·1")
    }

    @Test func narrowDropsCopiesFromTheRightBeforeCuttingTheSession() {
        let session = StatusLine.Session(fiveHour: 41, sevenDay: 63)
        // "Code 41·63  ▸A 37·62  B 92·✕  C 12·30" is 37 columns.
        #expect(plain(three, session, columns: 37) == "Code 41·63  ▸A 37·62  B 92·✕  C 12·30")
        #expect(plain(three, session, columns: 36) == "Code 41·63  ▸A 37·62  B 92·✕")
        #expect(plain(three, session, columns: 20) == "Code 41·63  ▸A 37·62")
        #expect(plain(three, session, columns: 19) == "Code 41·63")
        #expect(plain(three, session, columns: 10) == "Code 41·63")
        #expect(plain(three, session, columns: 6) == "Code …")
        #expect(plain(three, session, columns: 1) == "…")
        // Without a session, the first copy is the one cut short.
        #expect(plain(three, columns: 4) == "▸A …")
    }
}
