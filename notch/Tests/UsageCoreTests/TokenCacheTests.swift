import Foundation
import Testing
@testable import UsageCore

@Suite struct TokenCacheTests {
    static let me = "aaaaaaaa-0000-0000-0000-000000000001"
    static let someoneElse = "bbbbbbbb-0000-0000-0000-000000000002"
    static let prod = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let other = "cccccccc-0000-0000-0000-000000000003"
    static let org = "11111111-2222-3333-4444-555555555555"
    static let now = Date(timeIntervalSince1970: 2_000_000_000)

    static func key(_ client: String, _ scopes: String, owner: String? = nil) -> String {
        let base = "\(client):\(org):https://api.anthropic.com:\(scopes)"
        return owner.map { "acct:\($0)|\(base)" } ?? base
    }

    static func entry(_ token: String, expiresIn seconds: TimeInterval) -> [String: Any] {
        ["token": token, "refreshToken": "never-read", "expiresAt": (now.timeIntervalSince1970 + seconds) * 1000,
         "subscriptionType": "max"]
    }

    static func select(_ cache: [String: Any], account: String? = me) throws -> TokenSelection {
        try TokenCache.select(decrypted: JSONSerialization.data(withJSONObject: cache), accountUUID: account, now: now)
    }

    static func picked(_ cache: [String: Any], account: String? = me) throws -> String? {
        guard case .usable(let token) = try select(cache, account: account) else { return nil }
        return token.token
    }

    @Test func prefersProductionClientWithFullScopes() throws {
        let result = try Self.select([
            Self.key(Self.other, "user:inference user:profile user:sessions"): Self.entry("other-client", expiresIn: 9000),
            Self.key(Self.prod, "user:profile"): Self.entry("profile-only", expiresIn: 9000),
            Self.key(Self.prod, "user:inference user:profile"): Self.entry("right", expiresIn: 3600),
        ])
        guard case .usable(let token) = result else { Issue.record("\(result)"); return }
        #expect(token.token == "right")
        #expect(token.subscriptionType == "max")
        #expect(token.organization == Self.org)
        #expect(token.scopes == ["user:inference", "user:profile"])
    }

    @Test func dropsOtherAccountsAndHonoursDeletionMarkers() throws {
        let full = "user:inference user:profile"
        let result = try Self.select([
            Self.key(Self.prod, full, owner: Self.someoneElse): Self.entry("not-mine", expiresIn: 9000),
            // A null scoped entry deletes its legacy alias.
            Self.key(Self.prod, full): Self.entry("deleted-legacy", expiresIn: 9000),
            Self.key(Self.prod, full, owner: Self.me): NSNull(),
            Self.key(Self.prod, "user:profile", owner: Self.me): Self.entry("mine", expiresIn: 600),
        ])
        guard case .usable(let token) = result else { Issue.record("\(result)"); return }
        #expect(token.token == "mine")
    }

    @Test func reportsExpiredWhenNothingIsUsable() throws {
        let result = try Self.select([
            Self.key(Self.prod, "user:inference user:profile"): Self.entry("old", expiresIn: -60),
            // Inside the two-minute margin counts as expired too.
            Self.key(Self.prod, "user:profile"): Self.entry("about-to-go", expiresIn: 60),
        ])
        #expect(result == .expired(latest: Self.now.addingTimeInterval(60)))
    }

    @Test func needsTheProfileScope() throws {
        let result = try Self.select([Self.key(Self.prod, "user:inference"): Self.entry("no-profile", expiresIn: 9000)])
        #expect(result == .none)
    }

    @Test func parsesKeysWithColonsInScopes() {
        let k = TokenCache.parseKey(Self.key(Self.prod.uppercased(), "user:inference  user:profile"))
        #expect(k?.clientID == Self.prod)
        #expect(k?.scopes == ["user:inference", "user:profile"])
        #expect(TokenCache.parseKey("not-a-uuid:\(Self.org):https://api.anthropic.com:user:profile") == nil)
        #expect(TokenCache.parseKey("\(Self.prod):\(Self.org):https://example.com:user:profile") == nil)
    }

    @Test func aScopedEntryReplacesItsLegacyAlias() throws {
        let full = "user:inference user:profile"
        // The legacy alias would win on expiry, but the scoped entry is the live one.
        #expect(try Self.picked([
            Self.key(Self.prod, full): Self.entry("legacy", expiresIn: 9000),
            Self.key(Self.prod.uppercased(), full, owner: Self.me.uppercased()): Self.entry("scoped", expiresIn: 600),
        ]) == "scoped")
    }

    @Test func withoutAKnownAccountOnlyLegacyKeysCount() throws {
        let cache: [String: Any] = [
            Self.key(Self.prod, "user:inference user:profile", owner: Self.me): Self.entry("scoped", expiresIn: 9000),
            Self.key(Self.prod, "user:profile"): Self.entry("legacy", expiresIn: 600),
        ]
        #expect(try Self.picked(cache, account: nil) == "legacy")
        #expect(try Self.picked(cache, account: "not-a-uuid") == "legacy")
    }

    @Test func ranksScopesBeforeExpiry() throws {
        // Among non-production clients: more scopes first, then the later expiry.
        #expect(try Self.picked([
            Self.key(Self.other, "user:profile"): Self.entry("fewer", expiresIn: 9000),
            Self.key(Self.other, "user:profile user:sessions"): Self.entry("more", expiresIn: 600),
        ]) == "more")
        #expect(try Self.picked([
            Self.key(Self.other, "user:inference user:profile"): Self.entry("sooner", expiresIn: 600),
            Self.key(Self.someoneElse, "user:inference user:profile"): Self.entry("later", expiresIn: 9000),
        ]) == "later")
    }

    @Test func breaksExactTiesTheSameWayEveryTime() throws {
        let laterOrg = "99999999-2222-3333-4444-555555555555"
        let cache: [String: Any] = [
            "\(Self.prod):\(laterOrg):https://api.anthropic.com:user:inference user:profile": Self.entry("second", expiresIn: 3600),
            Self.key(Self.prod, "user:inference user:profile"): Self.entry("first", expiresIn: 3600),
        ]
        for _ in 0..<20 { #expect(try Self.picked(cache) == "first") }
    }

    @Test func skipsMalformedEntries() throws {
        let profile = "user:profile"
        let result = try Self.select([
            Self.key(Self.prod, "user:inference user:profile"): ["token": "", "expiresAt": 9e15],
            Self.key(Self.prod, "user:inference user:profile user:a"): ["token": "no-expiry"],
            Self.key(Self.prod, "user:inference user:profile user:b"): ["token": "string-expiry", "expiresAt": "soon"],
            Self.key(Self.prod, "user:inference user:profile user:c"): "not an object",
            "acct:not-a-uuid|" + Self.key(Self.prod, "user:inference user:profile user:d"): Self.entry("bad-owner", expiresIn: 9000),
            "acct:\(Self.me)" + Self.key(Self.prod, "user:inference user:profile user:e"): Self.entry("no-bar", expiresIn: 9000),
            Self.key(Self.other, profile): Self.entry("valid", expiresIn: 600),
        ])
        guard case .usable(let token) = result else { Issue.record("\(result)"); return }
        #expect(token.token == "valid")
    }

    @Test func treatsTheTwoMinuteMarginAsExpired() throws {
        let key = Self.key(Self.prod, "user:profile")
        #expect(try Self.select([key: Self.entry("edge", expiresIn: 120)]) == .expired(latest: Self.now.addingTimeInterval(120)))
        #expect(try Self.picked([key: Self.entry("inside", expiresIn: 121)]) == "inside")
    }

    @Test func refusesCachesThatArentObjects() throws {
        #expect(throws: UsageError.unreadableTokenCache) {
            try TokenCache.select(decrypted: Data("[]".utf8), accountUUID: nil)
        }
        #expect(try Self.select([:]) == .none)
    }

    @Test func printingATokenNeverShowsIt() throws {
        let result = try Self.select([Self.key(Self.prod, "user:profile"): Self.entry("sk-ant-oat01-secret", expiresIn: 9000)])
        guard case .usable(let token) = result else { Issue.record("not usable"); return }
        let profile = Profile(letter: "B", dataDirectory: URL(filePath: "/tmp"))
        let snapshot = AccountSnapshot(profile: profile, token: token, account: nil, usage: .failure(.notSignedIn), fetchedAt: Self.now)
        var dumped = ""
        dump(snapshot, to: &dumped)
        for text in ["\(token)", String(reflecting: token), "\(result)", String(reflecting: result), "\(snapshot)", dumped] {
            #expect(!text.contains("secret"))
        }
        #expect("\(token)".contains(Self.prod))
    }
}

@Suite struct ProfileTests {
    @Test func lettersFromFolders() {
        #expect(Profile.letter(forFolder: "Claude") == "A")
        #expect(Profile.letter(forFolder: "Claude-B") == "B")
        #expect(Profile.letter(forFolder: "Claude-C") == "C")
        #expect(Profile.letter(forFolder: "Claude-A") == nil)
        #expect(Profile.letter(forFolder: "Claude-3p") == nil)
        #expect(Profile.letter(forFolder: "Claude-b") == nil)
        #expect(Profile.letter(forFolder: "ClaudeCode") == nil)
    }

    @Test func discoversOnlyFoldersWithConfig() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "profiles-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["Claude", "Claude-C", "Claude-B", "Claude-3p", "Claude-D"] {
            try FileManager.default.createDirectory(at: root.appending(path: name), withIntermediateDirectories: true)
        }
        for name in ["Claude", "Claude-C", "Claude-B", "Claude-3p"] {
            try Data("{}".utf8).write(to: root.appending(path: "\(name)/config.json"))
        }
        #expect(Profile.discover(in: root).map(\.letter) == ["A", "B", "C"])
    }

    @Test func anEmptyV2MeansSignedOut() throws {
        #expect(try ProfileConfig.parse(Data(#"{"oauth:tokenCacheV2":""}"#.utf8)).encryptedTokenCache == nil)
        #expect(try ProfileConfig.parse(Data(#"{"oauth:tokenCacheV2":null}"#.utf8)).encryptedTokenCache == nil)
        #expect(throws: UsageError.unreadableConfig) { try ProfileConfig.parse(Data("[]".utf8)) }
    }

    @Test func readsV2AndAccount() throws {
        let config = try ProfileConfig.parse(Data(#"{"oauth:tokenCache":"v1","oauth:tokenCacheV2":"v2","lastKnownAccountUuid":"u"}"#.utf8))
        #expect(config.encryptedTokenCache == "v2")
        #expect(config.accountUUID == "u")
    }
}
