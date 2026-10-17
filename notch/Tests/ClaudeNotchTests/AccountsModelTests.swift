import Foundation
import Testing
@testable import ClaudeNotch
@testable import UsageCore

private let b = Profile(letter: "B", dataDirectory: URL(filePath: "/tmp/Claude-B"))
private let team = "team-org"
private let personal = "personal-org"
private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func token(_ org: String, plan: String) -> AccessToken {
    AccessToken(
        token: "t", clientID: "c", organization: org, scopes: ["user:profile"],
        expiresAt: t0.addingTimeInterval(86400), subscriptionType: plan, rateLimitTier: nil
    )
}

private func login(_ org: String, active: Bool, plan: String = "team") -> Login {
    Login(profile: b, organization: org, isActive: active, token: .success(token(org, plan: plan)), accountUUID: nil)
}

private func read(_ logins: [Login]) -> ProfileLogins { ProfileLogins(profile: b, logins: .success(logins)) }

private func snapshot(_ org: String, active: Bool = true, at: Date, _ usage: Result<UsageReport, UsageError>) -> AccountSnapshot {
    AccountSnapshot(
        profile: b, organization: org, isActive: active, token: token(org, plan: "team"),
        account: AccountProfile(
            email: "me@example.com", accountUUID: nil, organizationUUID: org, organizationName: "Acme",
            organizationType: "claude_team", rateLimitTier: nil
        ),
        usage: usage, fetchedAt: at
    )
}

private let report = UsageReport(windows: [UsageWindow(label: "5-hour", percentUsed: 44, resetsAt: nil)], extraUsage: nil)

@MainActor
private func model() -> AccountsModel {
    let model = AccountsModel(reader: nil)
    model.show(profiles: [b], accounts: [])
    return model
}

@MainActor @Test func eachOrganizationIsAnAccountWithTheOneInUseFirst() {
    let model = model()
    let due = model.sync(read([login(personal, active: false, plan: "max"), login(team, active: true)]), now: t0)
    #expect(due.count == 2)
    let copy = try! #require(model.copies.first)
    #expect(copy.active?.organization == team)
    #expect(copy.others.map(\.organization) == [personal])

    model.apply([snapshot(team, at: t0, .success(report))])
    #expect(model.copies[0].active?.planLabel == "Team · Acme")
    #expect(model.copies[0].active?.email == "me@example.com")

    // Switching organizations in Claude swaps which one is in use, keeping both's numbers.
    _ = model.sync(read([login(personal, active: true, plan: "max"), login(team, active: false)]), now: t0)
    #expect(model.copies[0].active?.organization == personal)
    #expect(model.copies[0].others.first?.report == report)
}

@MainActor @Test func onlyDueAccountsAreRead() {
    let model = model()
    _ = model.sync(read([login(team, active: true)]), now: t0)
    model.apply([snapshot(team, at: t0, .success(report))])
    #expect(model.sync(read([login(team, active: true)]), now: t0.addingTimeInterval(60)).isEmpty)
    #expect(model.sync(read([login(team, active: true)]), now: t0.addingTimeInterval(PollPlan.interval)).count == 1)
}

@MainActor @Test func aPassingFailureKeepsTheLastNumbers() {
    let model = model()
    _ = model.sync(read([login(team, active: true)]), now: t0)
    model.apply([snapshot(team, at: t0, .success(report))])
    // Claude rewriting config.json mid-read.
    _ = model.sync(ProfileLogins(profile: b, logins: .failure(.unreadableConfig)), now: t0.addingTimeInterval(400))
    let account = try! #require(model.copies[0].active)
    #expect(account.report == report)
    #expect(account.error == .unreadableConfig)
    #expect(account.message == nil)
    #expect(account.status(now: t0.addingTimeInterval(400)) == "6m ago")
}

@MainActor @Test func signingOutClearsTheAccounts() {
    let model = model()
    _ = model.sync(read([login(team, active: true), login(personal, active: false)]), now: t0)
    model.apply([snapshot(team, at: t0, .success(report))])
    _ = model.sync(ProfileLogins(profile: b, logins: .failure(.notSignedIn)), now: t0)
    #expect(model.accounts.count == 1)
    #expect(model.copies[0].active?.organization == nil)
    #expect(model.copies[0].active?.message == "Sign in to Claude B")
}

@MainActor @Test func aRefusedKeychainStopsPolling() {
    let model = model()
    _ = model.sync(ProfileLogins(profile: b, logins: .failure(.keychain(errSecUserCanceled))), now: t0)
    #expect(model.keychainProblem == .keychain(errSecUserCanceled))
    #expect(model.copies[0].active?.message == "Waiting for Keychain access")
}

@MainActor @Test func rateLimitsBackOffPerAccount() {
    let model = model()
    _ = model.sync(read([login(team, active: true), login(personal, active: false)]), now: t0)
    model.apply([snapshot(team, at: t0, .success(report)), snapshot(personal, active: false, at: t0, .success(report))])

    var at = t0
    var waits: [TimeInterval] = []
    for _ in 0..<4 {
        model.apply([snapshot(team, at: at, .failure(.rateLimited(retryAfter: nil)))])
        let account = model.accounts.first { $0.organization == team }!
        waits.append(account.nextPoll.timeIntervalSince(at))
        at = account.nextPoll
    }
    #expect(waits == [300, 600, 1200, 2400])
    let limited = model.accounts.first { $0.organization == team }!
    #expect(limited.report == report)
    #expect(limited.status(now: at.addingTimeInterval(-1200))?.hasPrefix("retrying in 20m") == true)
    // The other organization isn't held back.
    #expect(model.accounts.first { $0.organization == personal }!.rateLimits == 0)

    // A real Retry-After wins, and a good read resets the count.
    model.apply([snapshot(team, at: at, .failure(.rateLimited(retryAfter: at.addingTimeInterval(900))))])
    #expect(model.accounts.first { $0.organization == team }!.nextPoll == at.addingTimeInterval(900))
    model.apply([snapshot(team, at: at, .success(report))])
    #expect(model.accounts.first { $0.organization == team }!.rateLimits == 0)
}

@MainActor @Test func openingThePanelDoesntCutABackoffShort() {
    let model = model()
    _ = model.sync(read([login(team, active: true), login(personal, active: false)]), now: t0)
    model.apply([
        snapshot(team, at: t0, .failure(.rateLimited(retryAfter: nil))),
        snapshot(personal, active: false, at: t0, .success(report)),
    ])
    let later = t0.addingTimeInterval(120)
    model.refreshIfStale(now: later)
    #expect(model.accounts.first { $0.organization == team }!.nextPoll == t0.addingTimeInterval(300))
    #expect(model.accounts.first { $0.organization == personal }!.nextPoll == later)
}

@MainActor @Test func aLeftoverOfAnotherAccountIsDropped() {
    let model = model()
    _ = model.sync(read([login(team, active: true), login(personal, active: false)]), now: t0)
    model.apply([snapshot(personal, active: false, at: t0, .failure(.otherAccount))])
    #expect(model.accounts.map(\.organization) == [team])
}

@MainActor @Test func settledOnceEveryAccountWasRead() {
    let model = model()
    #expect(!model.isSettled)
    _ = model.sync(read([login(team, active: true)]), now: t0)
    #expect(!model.isSettled)
    model.apply([snapshot(team, at: t0, .success(report))])
    #expect(model.isSettled)
}
