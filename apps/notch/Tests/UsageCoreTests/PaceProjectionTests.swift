import Foundation
import Testing
@testable import UsageCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let hour: TimeInterval = 3600
private let day: TimeInterval = 86400

private func window(_ label: String, _ percent: Double, resetsIn: TimeInterval?) -> UsageWindow {
    UsageWindow(label: label, percentUsed: percent, resetsAt: resetsIn.map { now.addingTimeInterval($0) })
}

@Suite struct PaceProjectionTests {
    @Test func fortyPercentAnHourInRunsOutTwoAndAHalfHoursIn() throws {
        // An hour into a 5-hour window, so it started an hour ago and resets in four.
        let out = try #require(PaceProjection.runsOut(window("5-hour", 40, resetsIn: 4 * hour), now: now))
        #expect(abs(out.timeIntervalSince(now.addingTimeInterval(-hour)) - 2.5 * hour) < 0.001)
    }

    @Test func onOrUnderAnEvenPaceThereIsNoProjection() {
        // 20% through, 20% used: it reaches 100% just as it resets.
        #expect(PaceProjection.runsOut(window("5-hour", 20, resetsIn: 4 * hour), now: now) == nil)
        #expect(PaceProjection.runsOut(window("5-hour", 12, resetsIn: 4 * hour), now: now) == nil)
        // A hair over an even pace is within the minute's grace.
        #expect(PaceProjection.runsOut(window("5-hour", 20.05, resetsIn: 4 * hour), now: now) == nil)
    }

    @Test func tooEarlyInTheWindowSaysNothing() {
        // 5% of the window gone, and already 30% used.
        #expect(PaceProjection.runsOut(window("5-hour", 30, resetsIn: 4.75 * hour), now: now) == nil)
        // Past 10%, the same rate projects.
        #expect(PaceProjection.runsOut(window("5-hour", 30, resetsIn: 4.4 * hour), now: now) != nil)
    }

    @Test func aFullWindowOrOneWithoutAResetIsLeftAlone() {
        #expect(PaceProjection.runsOut(window("5-hour", 100, resetsIn: 2 * hour), now: now) == nil)
        #expect(PaceProjection.runsOut(window("5-hour", 0, resetsIn: nil), now: now) == nil)
        #expect(PaceProjection.runsOut(window("Monthly", 80, resetsIn: day), now: now) == nil)
    }

    @Test func weeklyWindowsLastSevenDays() throws {
        #expect(PaceProjection.windowLength(window("Weekly · all models", 1, resetsIn: nil)) == 7 * day)
        #expect(PaceProjection.windowLength(window("Weekly · Fable", 1, resetsIn: nil)) == 7 * day)
        #expect(PaceProjection.windowLength(window("5-hour", 1, resetsIn: nil)) == 5 * hour)
        // 4 days in with 80% used: 5 days in total, two days before the reset.
        let weekly = window("Weekly · all models", 80, resetsIn: 3 * day)
        #expect(abs(try #require(PaceProjection.elapsedFraction(weekly, now: now)) - 4.0 / 7) < 1e-9)
        let out = try #require(PaceProjection.runsOut(weekly, now: now))
        #expect(abs(out.timeIntervalSince(now) - day) < 0.001)
    }
}
