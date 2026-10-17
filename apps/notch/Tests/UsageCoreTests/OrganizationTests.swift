import CryptoKit
import Foundation
import SQLite3
import Testing
@testable import UsageCore

private let me = "aaaaaaaa-0000-0000-0000-000000000001"
private let team = "77777777-0000-0000-0000-000000000007"
private let personal = "55555555-0000-0000-0000-000000000005"
private let prod = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
private let password = Data("fixture-password".utf8)
private let key = SafeStorage.deriveKey(password: password)

private func cacheKey(_ org: String, _ scopes: String = "user:inference user:profile") -> String {
    "acct:\(me)|\(prod):\(org):https://api.anthropic.com:\(scopes)"
}

private func entry(_ token: String, expiresIn seconds: TimeInterval, plan: String) -> [String: Any] {
    ["token": token, "refreshToken": "never-read", "expiresAt": (Date().timeIntervalSince1970 + seconds) * 1000,
     "subscriptionType": plan]
}

@Suite struct OrganizationLoginTests {
    @Test func oneLoginPerOrganization() throws {
        let cache: [String: Any] = [
            cacheKey(team): entry("team", expiresIn: 9000, plan: "team"),
            cacheKey(personal): entry("max", expiresIn: 9000, plan: "max"),
            // A partial-scope leftover in the same organization loses to the full login.
            cacheKey(personal, "user:profile"): entry("leftover", expiresIn: 99000, plan: "max"),
        ]
        let logins = try TokenCache.logins(decrypted: JSONSerialization.data(withJSONObject: cache), accountUUID: me)
        #expect(logins.map(\.organization) == [personal, team])
        guard case .usable(let max) = logins[0].selection, case .usable(let teamToken) = logins[1].selection else {
            Issue.record("\(logins)")
            return
        }
        #expect(max.token == "max")
        #expect(teamToken.token == "team")
    }

    @Test func eachOrganizationExpiresOnItsOwn() throws {
        let cache: [String: Any] = [
            cacheKey(team): entry("team", expiresIn: 9000, plan: "team"),
            cacheKey(personal): entry("max", expiresIn: -60, plan: "max"),
        ]
        let logins = try TokenCache.logins(decrypted: JSONSerialization.data(withJSONObject: cache), accountUUID: me)
        guard case .expired = logins[0].selection, case .usable = logins[1].selection else {
            Issue.record("\(logins)")
            return
        }
    }
}

@Suite struct PlanNameTests {
    @Test func plans() {
        #expect(PlanName.of(subscriptionType: "max", rateLimitTier: "default_claude_max_20x", organizationType: nil) == "Max 20x")
        #expect(PlanName.of(subscriptionType: "max", rateLimitTier: "default_claude_max_5x", organizationType: "claude_max") == "Max 5x")
        #expect(PlanName.of(subscriptionType: "max", rateLimitTier: nil, organizationType: nil) == "Max")
        #expect(PlanName.of(subscriptionType: "pro", rateLimitTier: nil, organizationType: nil) == "Pro")
        #expect(PlanName.of(subscriptionType: "team", rateLimitTier: "default_claude_max_5x", organizationType: nil) == "Team")
        #expect(PlanName.of(subscriptionType: nil, rateLimitTier: nil, organizationType: "claude_team") == "Team")
        #expect(PlanName.of(subscriptionType: nil, rateLimitTier: nil, organizationType: "claude_enterprise") == "Enterprise")
        #expect(PlanName.of(subscriptionType: nil, rateLimitTier: nil, organizationType: "claude_free") == "Free")
        #expect(PlanName.of(subscriptionType: nil, rateLimitTier: nil, organizationType: nil) == nil)
    }

    @Test func organizations() {
        #expect(PlanName.organization(name: "Acme", organizationType: "claude_team", subscriptionType: "team") == "Acme")
        #expect(PlanName.organization(name: "me@example.com's Organization", organizationType: "claude_max", subscriptionType: "max") == "Personal")
        #expect(PlanName.organization(name: nil, organizationType: nil, subscriptionType: "max") == "Personal")
        #expect(PlanName.organization(name: nil, organizationType: nil, subscriptionType: nil) == nil)
        #expect(PlanName.label(plan: "Team", organization: "Acme") == "Team · Acme")
        #expect(PlanName.label(plan: nil, organization: nil) == nil)
    }
}

/// A Chromium-style cookie database with `lastActiveOrg` rows.
func writeCookieDatabase(
    at url: URL, rows: [(host: String, value: String, encrypted: Data, updated: Int64)], modernSchema: Bool = true
) throws {
    var db: OpaquePointer?
    guard sqlite3_open(url.path(percentEncoded: false), &db) == SQLITE_OK else { throw UsageError.unreadableConfig }
    defer { sqlite3_close(db) }
    let columns = modernSchema ? ", last_update_utc INTEGER" : ""
    guard sqlite3_exec(db, "CREATE TABLE cookies (creation_utc INTEGER, host_key TEXT, name TEXT, value TEXT, encrypted_value BLOB\(columns))", nil, nil, nil) == SQLITE_OK
    else { throw UsageError.unreadableConfig }
    for row in rows {
        var statement: OpaquePointer?
        let sql = modernSchema
            ? "INSERT INTO cookies VALUES (?, ?, 'lastActiveOrg', ?, ?, ?)"
            : "INSERT INTO cookies VALUES (?, ?, 'lastActiveOrg', ?, ?)"
        sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int64(statement, 1, row.updated)
        sqlite3_bind_text(statement, 2, row.host, -1, transient)
        sqlite3_bind_text(statement, 3, row.value, -1, transient)
        _ = row.encrypted.withUnsafeBytes { sqlite3_bind_blob(statement, 4, $0.baseAddress, Int32(row.encrypted.count), transient) }
        if modernSchema { sqlite3_bind_int64(statement, 5, row.updated) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw UsageError.unreadableConfig }
        sqlite3_finalize(statement)
    }
}

/// Encrypts a cookie value the way Chromium does, with or without the host's hash in front.
func encryptedCookie(_ value: String, host: String, hashed: Bool = true) throws -> Data {
    let plain = (hashed ? Data(SHA256.hash(data: Data(host.utf8))) : Data()) + Data(value.utf8)
    return Data(base64Encoded: try SafeStorage.encrypt(plain, key: key))!
}

@Suite struct ActiveOrganizationTests {
    func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "active-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func readsTheNewestEncryptedCookie() throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        try writeCookieDatabase(at: dir.appending(path: "Cookies"), rows: [
            (".claude.ai", "", try encryptedCookie(personal, host: ".claude.ai"), 100),
            ("claude.ai", "", try encryptedCookie(team.uppercased(), host: "claude.ai"), 200),
        ])
        let profile = Profile(letter: "B", dataDirectory: dir)
        #expect(ActiveOrganization.cookie(in: profile, key: key) == team)
    }

    @Test func readsOlderFormats() throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir.appending(path: "Network"), withIntermediateDirectories: true)
        // No last_update_utc column, no host hash, and a database under Network/.
        try writeCookieDatabase(at: dir.appending(path: "Network/Cookies"), rows: [
            (".claude.ai", "", try encryptedCookie(personal, host: ".claude.ai", hashed: false), 100),
        ], modernSchema: false)
        #expect(ActiveOrganization.cookie(in: Profile(letter: "B", dataDirectory: dir), key: key) == personal)
    }

    @Test func plainValuesAndGarbage() throws {
        let plain = ActiveOrganization.StoredCookie(host: "claude.ai", value: Data(team.utf8), encryptedValue: Data())
        #expect(ActiveOrganization.value(of: plain, key: key) == team)
        let wrongKey = ActiveOrganization.StoredCookie(
            host: "claude.ai", value: Data(), encryptedValue: try encryptedCookie(team, host: "claude.ai")
        )
        #expect(ActiveOrganization.value(of: wrongKey, key: SafeStorage.deriveKey(password: Data("other".utf8))) == nil)
        let notAnOrganization = ActiveOrganization.StoredCookie(host: "claude.ai", value: Data("hello".utf8), encryptedValue: Data())
        #expect(ActiveOrganization.value(of: notAnOrganization, key: key) == nil)
    }

    @Test func fallsBackToTheNewestUsageSample() throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let history = #"{"version":2,"samples":[{"t":3,"org":"\#(team)","u":{}},{"t":9,"org":"\#(personal)","u":{"fh":1}},{"t":5,"org":"x"}]}"#
        try Data(history.utf8).write(to: dir.appending(path: "plan-usage-history.json"))
        let profile = Profile(letter: "B", dataDirectory: dir)
        #expect(ActiveOrganization.cookie(in: profile, key: key) == nil)
        #expect(ActiveOrganization.read(profile, key: key) == personal)
    }
}

@Suite struct ReaderOrganizationTests {
    func profile(cache: [String: Any], cookie: String?) throws -> Profile {
        let folder = FileManager.default.temporaryDirectory.appending(path: "orgs-\(UUID())/Claude-B")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let config: [String: Any] = [
            "lastKnownAccountUuid": me,
            "oauth:tokenCacheV2": try SafeStorage.encrypt(JSONSerialization.data(withJSONObject: cache), key: key),
        ]
        try JSONSerialization.data(withJSONObject: config).write(to: folder.appending(path: "config.json"))
        if let cookie {
            try writeCookieDatabase(at: folder.appending(path: "Cookies"), rows: [
                (".claude.ai", "", try encryptedCookie(cookie, host: ".claude.ai"), 1),
            ])
        }
        return Profile(letter: "B", dataDirectory: folder)
    }

    var reader: AccountReader { AccountReader(client: UsageClient(session: StubProtocol.session)) { password } }

    @Test func theCookieSaysWhichOrganizationIsInUse() async throws {
        // The Max login ranks higher on its own (later expiry), but the copy is working in the Team.
        let profile = try profile(cache: [
            cacheKey(team): entry("200", expiresIn: 9000, plan: "team"),
            cacheKey(personal): entry("200", expiresIn: 99000, plan: "max"),
        ], cookie: team)
        defer { try? FileManager.default.removeItem(at: profile.dataDirectory.deletingLastPathComponent()) }

        let read = try #require(await reader.logins(of: [profile]).first)
        #expect(read.activeSource == .cookie)
        let logins = try read.logins.get()
        #expect(logins.map(\.organization) == [team, personal])
        #expect(logins.map(\.isActive) == [true, false])

        let snapshots = await reader.snapshots(of: [profile])
        #expect(snapshots.map(\.organization) == [team, personal])
        #expect(snapshots.map(\.plan) == ["Team", "Max"])
        #expect(snapshots.allSatisfy { $0.usage.map(\.fiveHour?.percentUsed) == .success(12) })
    }

    @Test func withoutACookieTheBestLoginIsInUse() async throws {
        let profile = try profile(cache: [
            cacheKey(team): entry("200", expiresIn: 9000, plan: "team"),
            cacheKey(personal, "user:profile"): entry("200", expiresIn: 99000, plan: "max"),
        ], cookie: nil)
        defer { try? FileManager.default.removeItem(at: profile.dataDirectory.deletingLastPathComponent()) }
        let read = try #require(await reader.logins(of: [profile]).first)
        #expect(read.activeSource == .bestLogin)
        #expect(try read.logins.get().first { $0.isActive }?.organization == team)
    }

    @Test func anOrganizationWithNoLoginYet() async throws {
        let other = "99999999-0000-0000-0000-000000000009"
        let profile = try profile(cache: [cacheKey(team): entry("200", expiresIn: 9000, plan: "team")], cookie: other)
        defer { try? FileManager.default.removeItem(at: profile.dataDirectory.deletingLastPathComponent()) }
        let snapshots = await reader.snapshots(of: [profile])
        #expect(snapshots.map(\.organization) == [other, team])
        #expect(snapshots[0].isActive)
        #expect(snapshots[0].usage == .failure(.noLogin))
    }

    @Test func dropsALeftoverLoginOfAnotherAccount() async throws {
        let profile = try profile(cache: [
            cacheKey(team): entry("200", expiresIn: 9000, plan: "team"),
            // A legacy key carries no owner; the profile call says whose it is.
            "\(prod):\(personal):https://api.anthropic.com:user:inference user:profile": entry("someone-else", expiresIn: 9000, plan: "max"),
        ], cookie: team)
        defer { try? FileManager.default.removeItem(at: profile.dataDirectory.deletingLastPathComponent()) }
        let reader = self.reader
        #expect(await reader.snapshots(of: [profile]).map(\.organization) == [team])
        // Not read again.
        #expect(try await reader.logins(of: [profile]).first?.logins.get().map(\.organization) == [team])
    }
}
