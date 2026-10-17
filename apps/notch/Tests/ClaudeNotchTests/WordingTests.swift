import Foundation
import Testing
@testable import UsageCore
@testable import ClaudeNotch

let now = Date(timeIntervalSince1970: 1_800_000_000)

func window(_ label: String, _ percent: Double, resetsIn: TimeInterval?) -> UsageWindow {
    UsageWindow(label: label, percentUsed: percent, resetsAt: resetsIn.map { now.addingTimeInterval($0) })
}

@Test func resetWithinADayCountsDown() {
    #expect(resetText(window("5-hour", 40, resetsIn: 2 * 3600 + 10 * 60), now: now) == "resets in 2h 10m")
}

@Test func resetBeyondADayCountsDownToo() {
    #expect(resetText(window("Weekly · all models", 40, resetsIn: 3 * 86400 + 4 * 3600), now: now) == "resets in 3d 4h")
}

@Test func fullWindowCountsDownToWhenItComesBack() {
    #expect(resetText(window("5-hour", 100, resetsIn: 2 * 3600 + 41 * 60 + 20), now: now) == "back in 2h 41m")
    #expect(resetText(window("Weekly · Fable", 100, resetsIn: 2 * 86400 + 3600), now: now) == "back in 2d 1h")
}

@Test func theLastTenMinutesShowSeconds() {
    #expect(resetText(window("5-hour", 100, resetsIn: 4 * 60 + 12), now: now) == "back in 4:12")
    #expect(countdown(10 * 60) == "10m")
    #expect(countdown(10 * 60 - 0.5) == "9:59")
    #expect(countdown(5) == "0:05")
}

@Test func aResetThatHasPassedBeforeTheNextRead() {
    #expect(resetText(window("5-hour", 100, resetsIn: -30), now: now) == "back now")
    #expect(resetText(window("5-hour", 60, resetsIn: -30), now: now) == "resets now")
}

@Test func hoveredRowsTellTheClock() {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)
    let noon = today.addingTimeInterval(12 * 3600), later = today.addingTimeInterval(16 * 3600 + 19 * 60)
    let time = later.formatted(.dateTime.hour().minute())
    let full = UsageWindow(label: "5-hour", percentUsed: 100, resetsAt: later)
    #expect(resetText(full, now: noon, clock: true) == "back at \(time)")
    let half = UsageWindow(label: "5-hour", percentUsed: 50, resetsAt: later)
    #expect(resetText(half, now: noon, clock: true) == "resets at \(time)")
}

@Test func clockNamesTheDayOnlyWhenItIsntToday() {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)
    let noon = today.addingTimeInterval(12 * 3600)
    func day(_ n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: today)!.addingTimeInterval(9 * 3600) }
    let time = day(0).formatted(.dateTime.hour().minute())
    #expect(clockText(day(0), now: noon) == time)
    #expect(clockText(day(0), now: noon, atToday: true) == "at \(time)")
    #expect(clockText(day(1), now: noon) == "tomorrow \(time)")
    #expect(clockText(day(3), now: noon) == "\(day(3).formatted(.dateTime.weekday(.abbreviated))) \(time)")
    // A week out, the weekday would be today's.
    #expect(clockText(day(7), now: noon) == "\(day(7).formatted(.dateTime.day().month(.abbreviated))) \(time)")
}

@Test func peeksShowTheCountdownAndTheClock() {
    let full = window("5-hour", 100, resetsIn: 2 * 3600 + 41 * 60)
    #expect(resetTextWithClock(full, now: now) == "back in 2h 41m · \(clockText(full.resetsAt!, now: now))")
    #expect(resetTextWithClock(window("5-hour", 0, resetsIn: nil), now: now) == "not started")
}

@Test func aFullWindowDrainsAsItsResetNears() {
    #expect(waitFraction(window("5-hour", 100, resetsIn: 2.5 * 3600), now: now) == 0.5)
    #expect(waitFraction(window("5-hour", 100, resetsIn: -60), now: now) == 0)
    #expect(waitFraction(window("5-hour", 99, resetsIn: 3600), now: now) == nil)
    #expect(waitFraction(window("5-hour", 100, resetsIn: nil), now: now) == nil)
}

@Test func anAccountIsBackWhenEveryFullWindowHasReset() {
    let both = UsageReport(windows: [
        window("5-hour", 100, resetsIn: 3600), window("Weekly · all models", 100, resetsIn: 2 * 86400),
        window("Weekly · Fable", 40, resetsIn: 86400),
    ], extraUsage: nil)
    #expect(both.isOut)
    #expect(both.backAt == now.addingTimeInterval(2 * 86400))
    let unknown = UsageReport(windows: [window("5-hour", 100, resetsIn: 3600), window("Weekly · Fable", 100, resetsIn: nil)], extraUsage: nil)
    #expect(unknown.isOut && unknown.backAt == nil)
    let fine = UsageReport(windows: [window("5-hour", 60, resetsIn: 3600)], extraUsage: nil)
    #expect(!fine.isOut && fine.backAt == nil)
}

@MainActor @Test func theCountdownBesideTheRingsWaitsForEveryCopyToBeOut() {
    func copy(_ letter: String, fiveHour percent: Double, backIn: TimeInterval) -> (Profile, AccountsModel.Account) {
        let profile = Profile(letter: letter, dataDirectory: URL(filePath: "/tmp/Claude-\(letter)"))
        var account = AccountsModel.Account(profile: profile, organization: "o")
        account.report = UsageReport(windows: [window("5-hour", percent, resetsIn: backIn)], extraUsage: nil)
        return (profile, account)
    }
    let model = AccountsModel(reader: nil)
    let out = [copy("A", fiveHour: 100, backIn: 3600), copy("B", fiveHour: 100, backIn: 600), copy("C", fiveHour: 100, backIn: 7200)]
    model.show(profiles: out.map(\.0), accounts: out.map(\.1))
    #expect(model.soonestBack?.letter == "B")
    #expect(model.soonestBack?.at == now.addingTimeInterval(600))

    let oneLeft = [out[0], out[1], copy("C", fiveHour: 70, backIn: 7200)]
    model.show(profiles: oneLeft.map(\.0), accounts: oneLeft.map(\.1))
    #expect(model.soonestBack == nil)
}

@MainActor @Test func messagesPerState() {
    var account = AccountsModel.Account(profile: Profile(letter: "B", dataDirectory: URL(filePath: "/tmp")), organization: "o")
    #expect(account.message == "Reading…")
    account.error = .tokenExpired(now)
    #expect(account.message == "Open Claude B to update")
    #expect(account.isStale)
    account.error = .notSignedIn
    #expect(account.message == "Sign in to Claude B")
    account.error = .unexpectedResponse
    #expect(account.message == "Usage unavailable")
    account.error = .noLogin
    #expect(account.message == "No login for this organization yet")
    #expect(account.isStale)
}

@MainActor @Test func anOrganizationNotInUseIsRenewedBySwitchingToIt() {
    var account = AccountsModel.Account(profile: Profile(letter: "B", dataDirectory: URL(filePath: "/tmp")), organization: "o")
    account.isActive = false
    account.error = .unauthorized
    #expect(account.message == "Switch Claude B to this organization to update")
}

@MainActor @Test func planLabels() {
    var account = AccountsModel.Account(profile: Profile(letter: "B", dataDirectory: URL(filePath: "/tmp")), organization: "o")
    #expect(account.planLabel == nil)
    account.plan = "Team"
    account.organizationLabel = "Acme"
    #expect(account.planLabel == "Team · Acme")
}
