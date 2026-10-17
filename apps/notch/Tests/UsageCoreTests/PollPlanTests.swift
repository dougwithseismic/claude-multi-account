import Foundation
import Testing
@testable import UsageCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)

@Test func accountsReadTogetherAreSpreadAcrossTheInterval() {
    #expect(PollPlan.stagger(index: 0, count: 3) == 0)
    #expect(PollPlan.stagger(index: 1, count: 3) == 100)
    #expect(PollPlan.stagger(index: 2, count: 3) == 200)
    #expect(PollPlan.stagger(index: 0, count: 1) == 0)
}

@Test func rateLimitBackoffDoublesFromFiveMinutesToSixHours() {
    let waits = (1...9).map { PollPlan.retryAfterRateLimit(failures: $0, retryAfter: nil, now: now).timeIntervalSince(now) }
    #expect(waits == [300, 600, 1200, 2400, 4800, 9600, 19200, 21600, 21600])
    #expect(PollPlan.retryAfterRateLimit(failures: 500, retryAfter: nil, now: now).timeIntervalSince(now) == 21600)
}

@Test func realRetryAfterIsHonouredWithinLimits() {
    let in20m = now.addingTimeInterval(1200)
    #expect(PollPlan.retryAfterRateLimit(failures: 1, retryAfter: in20m, now: now) == in20m)
    // Too soon or too far is kept between a minute and six hours.
    #expect(PollPlan.retryAfterRateLimit(failures: 1, retryAfter: now.addingTimeInterval(5), now: now) == now.addingTimeInterval(60))
    #expect(PollPlan.retryAfterRateLimit(failures: 1, retryAfter: now.addingTimeInterval(86400), now: now) == now.addingTimeInterval(21600))
}

@Test func weeklyPeakIsTheFullestWeeklyWindow() {
    let report = UsageReport(windows: [
        UsageWindow(label: "5-hour", percentUsed: 99, resetsAt: nil),
        UsageWindow(label: "Weekly · all models", percentUsed: 40, resetsAt: nil),
        UsageWindow(label: "Weekly · Fable", percentUsed: 70, resetsAt: nil),
    ], extraUsage: nil)
    #expect(report.weeklyPeak?.label == "Weekly · Fable")
    // A Team plan with only a per-model weekly window.
    let team = UsageReport(windows: [UsageWindow(label: "Weekly · Fable", percentUsed: 100, resetsAt: nil)], extraUsage: nil)
    #expect(team.weeklyPeak?.percentUsed == 100)
}

@Test func durations() {
    #expect(UsageFormat.duration(0) == "now")
    #expect(UsageFormat.duration(4 * 60 + 30) == "4m")
    #expect(UsageFormat.duration(2 * 3600 + 10 * 60) == "2h 10m")
    #expect(UsageFormat.duration(2 * 86400 + 3 * 3600) == "2d 3h")
}
