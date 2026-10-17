import Foundation
import Testing
@testable import ClaudeNotch
@testable import UsageCore

private func report(_ windows: (String, Double)...) -> UsageReport {
    UsageReport(windows: windows.map { UsageWindow(label: $0.0, percentUsed: $0.1, resetsAt: nil) }, extraUsage: nil)
}

@Suite struct LimitAlertTests {
    @Test func theFirstReadNeverAlerts() {
        #expect(LimitAlert.between(nil, report(("5-hour", 99))) == nil)
    }

    @Test func passingNinetyOnTheFiveHourWindow() {
        let alert = LimitAlert.between(report(("5-hour", 80)), report(("5-hour", 91)))
        #expect(alert == .near(UsageWindow(label: "5-hour", percentUsed: 91, resetsAt: nil)))
        // Already past it, or a weekly window: nothing.
        #expect(LimitAlert.between(report(("5-hour", 91)), report(("5-hour", 95))) == nil)
        #expect(LimitAlert.between(report(("Weekly · all models", 80)), report(("Weekly · all models", 95))) == nil)
    }

    @Test func runningOutBeatsGettingClose() {
        let alert = LimitAlert.between(
            report(("5-hour", 80), ("Weekly · Fable", 97)), report(("5-hour", 92), ("Weekly · Fable", 100))
        )
        #expect(alert == .out(UsageWindow(label: "Weekly · Fable", percentUsed: 100, resetsAt: nil)))
    }

    @Test func comingBack() {
        let alert = LimitAlert.between(report(("Weekly · Fable", 100)), report(("Weekly · Fable", 0)))
        #expect(alert == .back(UsageWindow(label: "Weekly · Fable", percentUsed: 0, resetsAt: nil)))
        #expect(alert?.window.label == "Weekly · Fable")
    }

    @Test func aWindowNotReadBeforeIsSkipped() {
        #expect(LimitAlert.between(report(("5-hour", 10)), report(("5-hour", 10), ("Weekly · Fable", 100))) == nil)
    }
}

private let b = Profile(letter: "B", dataDirectory: URL(filePath: "/tmp/Claude-B"))
private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func snapshot(_ org: String, active: Bool, _ percent: Double) -> AccountSnapshot {
    AccountSnapshot(
        profile: b, organization: org, isActive: active, token: nil, account: nil,
        usage: .success(report(("5-hour", percent))), fetchedAt: t0
    )
}

@MainActor @Test func theModelAlertsOnlyForTheOrganizationInUse() {
    let model = AccountsModel(reader: nil)
    var team = AccountsModel.Account(profile: b, organization: "team")
    team.report = report(("5-hour", 50))
    var personal = AccountsModel.Account(profile: b, organization: "personal")
    personal.isActive = false
    personal.report = report(("5-hour", 50))
    model.show(profiles: [b], accounts: [team, personal])

    var alerts: [(String, LimitAlert)] = []
    model.onAlert = { alerts.append(($0, $1)) }
    model.apply([snapshot("team", active: true, 95), snapshot("personal", active: false, 95)])
    #expect(alerts.count == 1)
    #expect(alerts.first?.0 == "B")
    #expect(alerts.first?.1 == .near(UsageWindow(label: "5-hour", percentUsed: 95, resetsAt: nil)))
}

@Suite struct PaceTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func howFarThroughItsWindowALimitIs() {
        let fiveHour = UsageWindow(label: "5-hour", percentUsed: 30, resetsAt: now.addingTimeInterval(3600))
        #expect(abs(elapsedFraction(fiveHour, now: now)! - 0.8) < 1e-9)
        let weekly = UsageWindow(label: "Weekly · Fable", percentUsed: 30, resetsAt: now.addingTimeInterval(3.5 * 86400))
        #expect(abs(elapsedFraction(weekly, now: now)! - 0.5) < 1e-9)
    }

    @Test func noTickWithoutAKnownWindow() {
        #expect(elapsedFraction(UsageWindow(label: "5-hour", percentUsed: 0, resetsAt: nil), now: now) == nil)
        #expect(elapsedFraction(UsageWindow(label: "Monthly", percentUsed: 5, resetsAt: now.addingTimeInterval(60)), now: now) == nil)
        // A reset further off than the window is long, or already past.
        #expect(elapsedFraction(UsageWindow(label: "5-hour", percentUsed: 5, resetsAt: now.addingTimeInterval(6 * 3600)), now: now) == nil)
        #expect(elapsedFraction(UsageWindow(label: "5-hour", percentUsed: 5, resetsAt: now.addingTimeInterval(-60)), now: now) == nil)
    }
}

@Suite struct PrivacyTests {
    @MainActor @Test func withoutDetailsAPlanLosesItsTeamName() {
        var account = AccountsModel.Account(profile: b, organization: "o")
        account.plan = "Team"
        account.organizationLabel = "Acme"
        #expect(account.planText(showsDetails: true) == "Team · Acme")
        #expect(account.planText(showsDetails: false) == "Team")
    }

    @Test func aLabelThatIsAnEmailIsNeverShownAsTheSafeOne() {
        let named = AccountStyle(letter: "B", label: "Work", color: .orange, hotkey: "2")
        #expect(named.safeLabel == "Work")
        let email = AccountStyle(letter: "B", label: "me@example.com", color: .orange, hotkey: "2")
        #expect(email.safeLabel == "Claude B")
    }

    @MainActor @Test func preferencesStartPrivateAndKeepWhatWasChosen() throws {
        let suite = "claude-notch-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = Preferences(defaults: defaults)
        #expect(!first.showDetails)
        #expect(first.openOn == .hover)
        #expect(first.limitAlerts && first.switchPeeks && first.haptics)

        first.showDetails = true
        first.openOn = .click
        first.haptics = false
        let second = Preferences(defaults: defaults)
        #expect(second.showDetails)
        #expect(second.openOn == .click)
        #expect(!second.haptics)
        #expect(second.limitAlerts)
    }

    @MainActor @Test func holdingOptionRevealsForAMoment() {
        let suite = "claude-notch-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        let state = NotchState()
        #expect(!state.showsDetails(preferences))
        state.revealHeld = true
        #expect(state.showsDetails(preferences))
        state.revealHeld = false
        preferences.showDetails = true
        #expect(state.showsDetails(preferences))
    }
}
