import Foundation
import Testing
@testable import ClaudeNotch
@testable import UsageCore

// The model writing the shared snapshot, and choosing the copy with the most room. `now`
// and `window` are WordingTests'.

private let secret = "sk-ant-oat01-not-a-real-token"
private let styles = [
    ProfileStyle(letter: "A", label: "Claude A", color: "#2F7BF5", hotkey: "1"),
    ProfileStyle(letter: "B", label: "me@example.com", color: "#F5822F", hotkey: "2"),
]

private func profile(_ letter: String) -> Profile { Profile(letter: letter, dataDirectory: URL(filePath: "/tmp/Claude-\(letter)")) }

private func login(_ letter: String, _ org: String) -> Login {
    Login(profile: profile(letter), organization: org, isActive: true, token: .success(token(org)), accountUUID: nil)
}

private func token(_ org: String) -> AccessToken {
    AccessToken(
        token: secret, clientID: "c", organization: org, scopes: ["user:profile"], expiresAt: now.addingTimeInterval(86400),
        subscriptionType: "team", rateLimitTier: nil
    )
}

private func read(_ letter: String, _ org: String, _ usage: Result<UsageReport, UsageError>, at: Date = now) -> AccountSnapshot {
    AccountSnapshot(
        profile: profile(letter), organization: org, isActive: true, token: token(org),
        account: AccountProfile(
            email: "me@example.com", accountUUID: "uuid-\(letter)", organizationUUID: org, organizationName: "Acme Secret Team",
            organizationType: "claude_team", rateLimitTier: nil
        ),
        usage: usage, fetchedAt: at
    )
}

private func usage(_ fiveHour: Double, weekly: Double = 10) -> UsageReport {
    UsageReport(windows: [window("5-hour", fiveHour, resetsIn: 3600), window("Weekly · all models", weekly, resetsIn: 3 * 86400)], extraUsage: nil)
}

private func temporaryFile() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "notch-sharing-\(UUID().uuidString)/claude-multi-account/usage.json")
}

/// A model that has read A and B once: A fine, B signed in to a Team and rate-limited.
@MainActor
private func readModel(sharingTo file: URL?) -> AccountsModel {
    let model = AccountsModel(reader: nil)
    model.snapshotFile = file
    model.show(profiles: [profile("A"), profile("B")], accounts: [])
    _ = model.sync(ProfileLogins(profile: profile("A"), logins: .success([login("A", "org-a")])), now: now)
    _ = model.sync(ProfileLogins(profile: profile("B"), logins: .success([login("B", "org-b")])), now: now)
    model.apply([read("A", "org-a", .success(usage(37))), read("B", "org-b", .failure(.rateLimited(retryAfter: nil)))])
    return model
}

@Suite struct SharingTests {
    @MainActor @Test func everyReadIsSharedWithoutTokensEmailsOrNames() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent().deletingLastPathComponent()) }
        _ = readModel(sharingTo: file)
        let data = try Data(contentsOf: file)
        let text = String(decoding: data, as: UTF8.self)
        for secret in [secret, "me@example.com", "Acme", "uuid-", "org-a", "org-b", "@"] {
            #expect(!text.contains(secret), "\(secret) is in the snapshot")
        }
        let mode = try FileManager.default.attributesOfItem(atPath: file.path(percentEncoded: false))[.posixPermissions] as? Int
        #expect(mode == 0o600)

        let snapshot = try #require(SharedSnapshot.decode(data))
        #expect(snapshot.updatedAt == now)
        #expect(snapshot.copies.map(\.letter) == ["A", "B"])
        #expect(snapshot.copies[0].state == .ok)
        #expect(snapshot.copies[0].plan == "Team")
        #expect(snapshot.copies[0].readAt == now)
        #expect(snapshot.copies[0].windows.map(\.percent) == [37, 10])
        // B has never read fine: no numbers, and it says why.
        #expect(snapshot.copies[1].state == .rateLimited)
        #expect(snapshot.copies[1].readAt == nil)
        #expect(snapshot.copies[1].windows.isEmpty)
    }

    @MainActor @Test func theSnapshotUsesTheProfilesNamesAndColours() {
        let model = readModel(sharingTo: nil)
        let copies = model.sharedSnapshot(updatedAt: now, styles: styles).copies
        #expect(copies.map(\.label) == ["Claude A", "Claude B"])
        #expect(copies.map(\.color) == ["#2F7BF5", "#F5822F"])
    }

    @MainActor @Test func aCopyComingToTheFrontIsWrittenAgain() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent().deletingLastPathComponent()) }
        let model = readModel(sharingTo: file)
        #expect(SharedSnapshot.read(from: file)?.copies.contains(where: \.inFront) == false)
        model.lastUsed = "B"
        let snapshot = try #require(SharedSnapshot.read(from: file))
        #expect(snapshot.copies.map(\.inFront) == [false, true])
        // Still the time of the last read, not of the switch.
        #expect(snapshot.updatedAt == now)
    }

    @MainActor @Test func nothingIsWrittenBeforeTheFirstReadOrWithoutAFile() {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent().deletingLastPathComponent()) }
        #expect(AccountsModel(reader: nil).snapshotFile == nil)
        let model = AccountsModel(reader: nil)
        model.snapshotFile = file
        model.show(profiles: [profile("A")], accounts: [])
        model.lastUsed = "A"
        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    }

    @MainActor @Test func aWriteThatFailsIsIgnored() {
        // A folder can't be made under /dev/null; the read still lands in the model.
        let model = readModel(sharingTo: URL(filePath: "/dev/null/claude-multi-account/usage.json"))
        #expect(model.copies[0].active?.report == usage(37))
    }

    @MainActor @Test func mostRoomIsTheCopyWhoseFullestWindowIsLowest() {
        let model = AccountsModel(reader: nil)
        func account(_ letter: String, _ report: UsageReport?, readAgo: TimeInterval = 60) -> AccountsModel.Account {
            var account = AccountsModel.Account(profile: profile(letter), organization: "o")
            account.report = report
            account.reportAt = report == nil ? nil : now.addingTimeInterval(-readAgo)
            return account
        }
        model.show(
            profiles: ["A", "B", "C", "D"].map(profile),
            accounts: [account("A", usage(10, weekly: 80)), account("B", usage(100)), account("C", usage(40, weekly: 20)), account("D", nil)]
        )
        #expect(model.mostRoom(now: now) == .copy("C"))

        // Every copy out: which one is back first, and nothing to switch to.
        model.show(profiles: ["A", "B"].map(profile), accounts: [account("A", usage(100)), account("B", usage(10, weekly: 100))])
        #expect(model.mostRoom(now: now) == .noRoom(back: BestCopy.Back(letter: "A", at: now.addingTimeInterval(3600))))
    }
}
