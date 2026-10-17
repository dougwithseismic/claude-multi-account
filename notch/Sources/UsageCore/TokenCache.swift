import Foundation

/// An access token picked from a profile's decrypted `oauth:tokenCacheV2`.
/// The refresh token is deliberately never read: using it would rotate it and
/// sign that copy of Claude out.
public struct AccessToken: Sendable, Equatable {
    public let token: String
    public let clientID: String
    public let organization: String
    public let scopes: [String]
    public let expiresAt: Date
    public let subscriptionType: String?
    public let rateLimitTier: String?
}

// The default descriptions would print the bearer token in any log line, `dump()` or test failure.
extension AccessToken: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        "AccessToken(client \(clientID), org \(organization), scopes \(scopes.joined(separator: " ")), expires \(expiresAt))"
    }

    public var debugDescription: String { description }

    public var customMirror: Mirror {
        Mirror(self, children: [
            "clientID": clientID, "organization": organization, "scopes": scopes, "expiresAt": expiresAt,
            "subscriptionType": subscriptionType as Any, "rateLimitTier": rateLimitTier as Any,
        ])
    }
}

public enum TokenSelection: Sendable, Equatable {
    case usable(AccessToken)
    /// Only expired tokens: that copy of Claude has to run to renew its own.
    case expired(latest: Date)
    case none
}

/// The login a copy holds for one organization.
public struct OrganizationLogin: Sendable, Equatable {
    public let organization: String
    public let selection: TokenSelection
}

/// The cache maps keys like `<clientId>:<orgUuid>:https://api.anthropic.com:<scopes>`,
/// sometimes prefixed `acct:<userUuid>|`, to `{ token, refreshToken, expiresAt (ms), … }`.
/// Selection follows openusage, which mirrors how the desktop app resolves its own login.
public enum TokenCache {
    static let apiHost = "https://api.anthropic.com"
    static let usageScope = "user:profile"
    static let inferenceScope = "user:inference"
    static let productionClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let expiryMargin: TimeInterval = 120

    struct Key: Hashable {
        let clientID: String
        let organization: String
        let scopes: [String]

        var sortKey: String { ([clientID, organization] + scopes).joined(separator: " ") }
    }

    /// The best login across every organization: the one Claude itself would use when
    /// nothing says which organization it's working in.
    public static func select(decrypted: Data, accountUUID: String?, now: Date = Date()) throws -> TokenSelection {
        best(of: try entries(decrypted, accountUUID: accountUUID), now: now)
    }

    /// The best login for each organization the account belongs to. One account can be in
    /// several (a personal Max plan and a Team, say), each with its own limits.
    public static func logins(decrypted: Data, accountUUID: String?, now: Date = Date()) throws -> [OrganizationLogin] {
        let all = try entries(decrypted, accountUUID: accountUUID)
        return Set(all.map(\.key.organization)).sorted().compactMap { organization in
            let selection = best(of: all.filter { $0.key.organization == organization }, now: now)
            return selection == .none ? nil : OrganizationLogin(organization: organization, selection: selection)
        }
    }

    /// The cache's entries that can read usage, sorted so equal ranks resolve the same way
    /// on every run (dictionary order is random per process).
    static func entries(_ decrypted: Data, accountUUID: String?) throws -> [(key: Key, value: Any)] {
        // A wrong key can slip past the padding check and give garbage, so bad JSON means
        // the same as a failed decrypt.
        guard let cache = (try? JSONSerialization.jsonObject(with: decrypted)) as? [String: Any] else {
            throw UsageError.unreadableTokenCache
        }
        return normalized(cache, accountUUID: accountUUID)
            .filter { $0.key.scopes.contains(usageScope) }
            .sorted { $0.key.sortKey < $1.key.sortKey }
    }

    static func best(of entries: [(key: Key, value: Any)], now: Date) -> TokenSelection {
        var latestExpired: Date?
        var best: (rank: (Int, Int, Int, Double), token: AccessToken)?
        for (key, raw) in entries {
            guard let entry = raw as? [String: Any],
                  let token = entry["token"] as? String, !token.isEmpty,
                  let expiresMs = (entry["expiresAt"] as? NSNumber)?.doubleValue, expiresMs.isFinite
            else { continue }
            let expiresAt = Date(timeIntervalSince1970: expiresMs / 1000)
            guard expiresAt.timeIntervalSince(now) > expiryMargin else {
                latestExpired = max(latestExpired ?? .distantPast, expiresAt)
                continue
            }
            let candidate = AccessToken(
                token: token, clientID: key.clientID, organization: key.organization, scopes: key.scopes,
                expiresAt: expiresAt,
                subscriptionType: entry["subscriptionType"] as? String,
                rateLimitTier: entry["rateLimitTier"] as? String
            )
            let full = key.scopes.contains(usageScope) && key.scopes.contains(inferenceScope)
            let rank = (
                full && key.clientID == productionClientID ? 1 : 0,
                full ? 1 : 0,
                key.scopes.count,
                expiresMs
            )
            if best == nil || rank > best!.rank { best = (rank, candidate) }
        }
        if let best { return .usable(best.token) }
        if let latestExpired { return .expired(latest: latestExpired) }
        return .none
    }

    /// Account-scoped keys (`acct:<user>|…`) replace their legacy alias, a null entry
    /// included (a deletion marker); keys scoped to another account are dropped.
    static func normalized(_ cache: [String: Any], accountUUID: String?) -> [Key: Any] {
        var legacy: [Key: Any] = [:]
        var scoped: [Key: Any] = [:]
        let active = accountUUID.flatMap(UUID.init(uuidString:))
        for (rawKey, entry) in cache.sorted(by: { $0.key < $1.key }) {
            var keyString = rawKey
            let isScoped = rawKey.hasPrefix("acct:")
            if isScoped {
                guard let bar = rawKey.firstIndex(of: "|"),
                      let owner = UUID(uuidString: String(rawKey.dropFirst(5)[..<bar])),
                      let active, owner == active
                else { continue }
                keyString = String(rawKey[rawKey.index(after: bar)...])
            }
            guard let key = parseKey(keyString) else { continue }
            if isScoped { scoped[key] = entry } else { legacy[key] = entry }
        }
        return legacy.merging(scoped) { _, scopedEntry in scopedEntry }
    }

    static func parseKey(_ value: String) -> Key? {
        guard let marker = value.range(of: ":\(apiHost):") else { return nil }
        let prefix = value[..<marker.lowerBound]
        guard let colon = prefix.firstIndex(of: ":") else { return nil }
        let clientID = prefix[..<colon].lowercased()
        let organization = prefix[prefix.index(after: colon)...].lowercased()
        guard UUID(uuidString: clientID) != nil, UUID(uuidString: organization) != nil else { return nil }
        let scopes = value[marker.upperBound...].split(whereSeparator: \.isWhitespace).map(String.init)
        return Key(clientID: clientID, organization: organization, scopes: scopes)
    }
}
