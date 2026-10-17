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

@Test func resetBeyondADayNamesTheDay() {
    #expect(resetText(window("Weekly · all models", 40, resetsIn: 3 * 86400), now: now).hasPrefix("resets "))
    #expect(!resetText(window("Weekly · all models", 40, resetsIn: 3 * 86400), now: now).contains(" in "))
}

@Test func fullWindowSaysWhenItComesBack() {
    #expect(resetText(window("Weekly · Fable", 100, resetsIn: 3600), now: now).hasPrefix("out until "))
}

@Test func unstartedFiveHourWindow() {
    #expect(resetText(window("5-hour", 0, resetsIn: nil), now: now) == "not started")
    #expect(resetText(window("Weekly · Fable", 0, resetsIn: nil), now: now) == "")
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
