import Foundation
import Testing
@testable import UsageCore

@Suite struct UsageDecodingTests {
    @Test func decodesWindowsAndPerModelLimits() throws {
        let body = #"""
        {"five_hour":{"utilization":42.5,"resets_at":"2026-10-17T14:29:59.580123+00:00"},
         "seven_day":{"utilization":100,"resets_at":"2026-10-18T13:59:59Z"},
         "seven_day_opus":{"utilization":88,"resets_at":"2026-10-18T13:59:59Z"},
         "seven_day_sonnet":null,
         "limits":[{"kind":"weekly_scoped","group":"weekly","percent":7,"resets_at":"2026-10-18T14:00:00.000Z",
                    "scope":{"model":{"id":null,"display_name":"Fable"}},"is_active":false},
                   {"kind":"something_new","percent":50}],
         "extra_usage":{"is_enabled":true,"monthly_limit":1000,"used_credits":250,"utilization":25,"currency":"EUR"},
         "iguana_necktie":{"anything":true}}
        """#
        let report = try UsageDecoding.report(from: Data(body.utf8))
        #expect(report.windows.map(\.label) == ["5-hour", "Weekly · all models", "Weekly · Fable"])
        #expect(report.fiveHour?.percentUsed == 42.5)
        #expect(report.weekly?.percentUsed == 100)
        // Microseconds are cut to milliseconds, not dropped.
        let reset = try #require(report.fiveHour?.resetsAt)
        #expect(abs(reset.timeIntervalSince1970 - 1_792_247_399.580) < 0.001)
        #expect(report.extraUsage == ExtraUsage(enabled: true, percentUsed: 25, spent: 2.5, monthlyLimit: 10, currency: "EUR"))
    }

    @Test func fallsBackToOldPerModelFields() throws {
        let body = #"{"five_hour":{"utilization":1,"resets_at":null},"seven_day":{"utilization":2,"resets_at":"2026-10-18T13:59:59Z"},"seven_day_opus":{"utilization":3,"resets_at":"2026-10-18T13:59:59Z"},"limits":[]}"#
        let report = try UsageDecoding.report(from: Data(body.utf8))
        #expect(report.windows.map(\.label) == ["5-hour", "Weekly · all models", "Weekly · Opus"])
        #expect(report.fiveHour?.resetsAt == nil)
        #expect(report.extraUsage == nil)
    }

    @Test func anOddFieldHidesOnlyItself() throws {
        let body = #"""
        {"five_hour":"soon","seven_day":{"utilization":30,"resets_at":"2026-10-18T13:59:59Z"},
         "seven_day_opus":{"utilization":"high"},
         "limits":[{"kind":"weekly_scoped","scope":"global","percent":5},
                   {"kind":"weekly_scoped","percent":"7"},
                   {"kind":"weekly_scoped","percent":9,"resets_at":null,"scope":{"model":{"display_name":"Fable"}}}],
         "extra_usage":[1,2]}
        """#
        let report = try UsageDecoding.report(from: Data(body.utf8))
        #expect(report.windows.map(\.label) == ["Weekly · all models", "Weekly · Fable"])
        #expect(report.windows.last?.percentUsed == 9)
        #expect(report.extraUsage == nil)
    }

    @Test func fallsBackWhenLimitsChangeShape() throws {
        let body = #"{"seven_day":{"utilization":2},"seven_day_sonnet":{"utilization":4},"limits":{"weekly_scoped":[]}}"#
        let report = try UsageDecoding.report(from: Data(body.utf8))
        #expect(report.windows.map(\.label) == ["Weekly · all models", "Weekly · Sonnet"])
    }

    @Test func decodesExtraUsageWithNulls() throws {
        let body = #"{"five_hour":{"utilization":0},"extra_usage":{"is_enabled":null,"monthly_limit":null,"used_credits":null,"utilization":null,"currency":null}}"#
        let report = try UsageDecoding.report(from: Data(body.utf8))
        #expect(report.extraUsage == ExtraUsage(enabled: false, percentUsed: nil, spent: nil, monthlyLimit: nil, currency: nil))
    }

    @Test func decodesASparseProfile() throws {
        let p = try UsageDecoding.profile(from: Data(#"{"account":null,"organization":{"uuid":null}}"#.utf8))
        #expect(p == AccountProfile(email: nil, accountUUID: nil, organizationUUID: nil, rateLimitTier: nil))
        #expect(throws: UsageError.unexpectedResponse) { try UsageDecoding.profile(from: Data("<html>".utf8)) }
    }

    @Test func refusesResponsesWithNoWindows() {
        #expect(throws: UsageError.unexpectedResponse) { try UsageDecoding.report(from: Data(#"{"error":"x"}"#.utf8)) }
        #expect(throws: UsageError.unexpectedResponse) { try UsageDecoding.report(from: Data("<html>".utf8)) }
    }

    @Test func decodesProfile() throws {
        let body = #"{"account":{"uuid":"u1","email":"me@example.com","has_claude_max":true},"organization":{"uuid":"o1","rate_limit_tier":"default_claude_max_20x"}}"#
        let p = try UsageDecoding.profile(from: Data(body.utf8))
        #expect(p == AccountProfile(email: "me@example.com", accountUUID: "u1", organizationUUID: "o1", rateLimitTier: "default_claude_max_20x"))
    }

    @Test func parsesDates() {
        #expect(UsageDecoding.date("2026-10-18T14:00:00Z") == Date(timeIntervalSince1970: 1_792_332_000))
        #expect(UsageDecoding.date("2026-10-18T14:00:00.5Z") == Date(timeIntervalSince1970: 1_792_332_000.5))
        #expect(UsageDecoding.date("2026-10-18T14:00:00.123456Z") == Date(timeIntervalSince1970: 1_792_332_000.123))
        #expect(UsageDecoding.date("2026-10-18T16:00:00+02:00") == Date(timeIntervalSince1970: 1_792_332_000))
        // No zone is taken as UTC.
        #expect(UsageDecoding.date("2026-10-18T14:00:00") == Date(timeIntervalSince1970: 1_792_332_000))
        #expect(UsageDecoding.date("2026-10-18T14:00:00.250000") == Date(timeIntervalSince1970: 1_792_332_000.25))
        #expect(UsageDecoding.date(nil) == nil)
        #expect(UsageDecoding.date("") == nil)
        #expect(UsageDecoding.date("tomorrow") == nil)
    }

    @Test func parsesRetryAfter() {
        let now = Date(timeIntervalSince1970: 1000)
        #expect(UsageClient.retryAfter("120", now: now) == Date(timeIntervalSince1970: 1120))
        #expect(UsageClient.retryAfter("0", now: now) == nil)
        #expect(UsageClient.retryAfter(nil, now: now) == nil)
        #expect(UsageClient.retryAfter("Wed, 21 Oct 2026 07:28:00 GMT", now: now) == Date(timeIntervalSince1970: 1_792_567_680))
        #expect(UsageClient.retryAfter(" 60 ", now: now) == Date(timeIntervalSince1970: 1060))
        for unknown in ["inf", "nan", "-5", "", "soon", "Wed, 21 Oct 2015 07:28:00 GMT"] {
            #expect(UsageClient.retryAfter(unknown, now: Date(timeIntervalSince1970: 1_792_000_000)) == nil, "\(unknown)")
        }
    }
}
