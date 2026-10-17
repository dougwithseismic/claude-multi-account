import Foundation

/// One organization's login in one copy of Claude, read from disk with no network call.
/// An account in a Team and on a personal plan has one per organization, each with its
/// own limits.
public struct Login: Sendable {
    public let profile: Profile
    public let organization: String
    /// The organization the copy is working in.
    public let isActive: Bool
    public let token: Result<AccessToken, UsageError>
    /// `lastKnownAccountUuid`, to spot a leftover login of an account that signed out.
    let accountUUID: String?
}

/// What a copy holds: its logins, the one in use first, or why it has none.
public struct ProfileLogins: Sendable {
    public let profile: Profile
    public let logins: Result<[Login], UsageError>
    /// How the organization in use was found.
    public var activeSource: ActiveSource? = nil
}

public enum ActiveSource: String, Sendable {
    /// Claude's `lastActiveOrg` cookie, set by its organization switcher.
    case cookie
    /// The newest sample in Claude's `plan-usage-history.json`.
    case usageHistory = "usage history"
    /// Neither said: the login Claude would pick by itself.
    case bestLogin = "best login"
}

/// Everything known about one organization in one copy after a read: who it is, how long
/// its login lasts, and its usage or why there isn't any.
public struct AccountSnapshot: Sendable {
    public let profile: Profile
    /// Nil when the copy has no readable login at all.
    public let organization: String?
    public let isActive: Bool
    public let token: AccessToken?
    public let account: AccountProfile?
    public let usage: Result<UsageReport, UsageError>
    public let fetchedAt: Date

    public var plan: String? {
        PlanName.of(
            subscriptionType: token?.subscriptionType, rateLimitTier: token?.rateLimitTier ?? account?.rateLimitTier,
            organizationType: account?.organizationType
        )
    }

    /// The organization's name for a Team, else "Personal".
    public var organizationLabel: String? {
        PlanName.organization(
            name: account?.organizationName, organizationType: account?.organizationType,
            subscriptionType: token?.subscriptionType
        )
    }

    /// By letter, the organization in use first.
    static func ordered(_ a: AccountSnapshot, _ b: AccountSnapshot) -> Bool {
        (a.profile.letter, a.isActive ? 0 : 1, a.organization ?? "") < (b.profile.letter, b.isActive ? 0 : 1, b.organization ?? "")
    }
}

/// Reads every profile's logins and usage. The Keychain is read once per instance, the
/// key kept in memory only.
public actor AccountReader {
    static let profileLifetime: TimeInterval = 12 * 60 * 60

    let client: UsageClient
    let readPassword: @Sendable () throws -> Data
    var key: Data?
    /// A failed Keychain read, kept for the rest of one `logins` call so a refused prompt
    /// isn't shown again for every profile.
    var keyFailure: Error?
    /// Each login's email and organization, which rarely change, so the profile call isn't
    /// made on every poll.
    var profiles: [String: (profile: AccountProfile, at: Date)] = [:]
    /// Logins found to belong to another account, skipped until they're replaced.
    var otherAccounts: Set<String> = []

    public init(client: UsageClient = UsageClient()) {
        self.init(client: client, readPassword: SafeStorage.keychainPassword)
    }

    init(client: UsageClient, readPassword: @escaping @Sendable () throws -> Data) {
        self.client = client
        self.readPassword = readPassword
    }

    /// Every login of every profile, read and fetched together, by letter, the organization
    /// in use first.
    public func snapshots(of profiles: [Profile]) async -> [AccountSnapshot] {
        let reads = logins(of: profiles)
        let all = await withTaskGroup(of: AccountSnapshot.self) { group in
            for read in reads {
                switch read.logins {
                case .success(let logins):
                    for login in logins { group.addTask { await self.snapshot(of: login) } }
                case .failure(let error):
                    let snapshot = Self.failed(read.profile, error)
                    group.addTask { snapshot }
                }
            }
            var all: [AccountSnapshot] = []
            for await snapshot in group { all.append(snapshot) }
            return all
        }
        return all.filter { $0.usage != .failure(.otherAccount) }.sorted(by: AccountSnapshot.ordered)
    }

    /// Each profile's logins, from disk only.
    public func logins(of profiles: [Profile]) -> [ProfileLogins] {
        keyFailure = nil
        return profiles.map { profile in
            switch logins(in: profile) {
            case .success(let (logins, source)): ProfileLogins(profile: profile, logins: .success(logins), activeSource: source)
            case .failure(let error): ProfileLogins(profile: profile, logins: .failure(error))
            }
        }
    }

    /// One login's usage, and its email and organization when they're not known yet.
    public func snapshot(of login: Login) async -> AccountSnapshot {
        let accessToken: AccessToken
        switch login.token {
        case .failure(let error):
            return AccountSnapshot(
                profile: login.profile, organization: login.organization, isActive: login.isActive,
                token: nil, account: nil, usage: .failure(error), fetchedAt: Date()
            )
        case .success(let token):
            accessToken = token
        }
        let cacheKey = "\(login.profile.letter)|\(login.organization)"
        let cached = profiles[cacheKey].flatMap { Date().timeIntervalSince($0.at) < Self.profileLifetime ? $0.profile : nil }
        let client = self.client
        async let usage = Self.usageResult(client, accessToken.token)
        // The profile is for labels only; its failure never hides usage.
        async let fetched = cached == nil ? try? client.profile(token: accessToken.token) : nil
        let account = await fetched ?? cached
        if let fresh = await fetched { profiles[cacheKey] = (fresh, Date()) }

        var result = await usage
        if let owner = account?.accountUUID, let expected = login.accountUUID,
           owner.caseInsensitiveCompare(expected) != .orderedSame {
            otherAccounts.insert(Self.loginKey(login.profile, accessToken))
            result = .failure(.otherAccount)
        }
        return AccountSnapshot(
            profile: login.profile, organization: login.organization, isActive: login.isActive,
            token: accessToken, account: account, usage: result, fetchedAt: Date()
        )
    }

    func logins(in profile: Profile) -> Result<([Login], ActiveSource), UsageError> {
        do {
            let config = try ProfileConfig.read(profile)
            guard let encrypted = config.encryptedTokenCache else { return .failure(.notSignedIn) }
            let key = try safeStorageKey()
            let decrypted = try SafeStorage.decrypt(base64: encrypted, key: key)
            let found = try TokenCache.logins(decrypted: decrypted, accountUUID: config.accountUUID).filter {
                guard case .usable(let token) = $0.selection else { return true }
                return !otherAccounts.contains(Self.loginKey(profile, token))
            }
            guard let first = found.first else { return .failure(.notSignedIn) }

            // The cookie is what Claude's organization switcher sets. Without it, the newest
            // usage sample, then the login Claude would pick by itself.
            let cookie = ActiveOrganization.cookie(in: profile, key: key)
            let history = ActiveOrganization.lastUsageSample(in: profile).flatMap { org in
                found.contains { $0.organization == org } ? org : nil
            }
            var best: String?
            if case .usable(let token) = try TokenCache.select(decrypted: decrypted, accountUUID: config.accountUUID) {
                best = token.organization
            }
            let active = cookie ?? history ?? best ?? first.organization
            let source: ActiveSource = cookie != nil ? .cookie : history != nil ? .usageHistory : .bestLogin

            var logins = found.map {
                Login(
                    profile: profile, organization: $0.organization, isActive: $0.organization == active,
                    token: Self.token($0.selection), accountUUID: config.accountUUID
                )
            }
            if !found.contains(where: { $0.organization == active }) {
                // Working in an organization it hasn't made a login for yet.
                logins.append(Login(
                    profile: profile, organization: active, isActive: true, token: .failure(.noLogin),
                    accountUUID: config.accountUUID
                ))
            }
            let sorted = logins.sorted { ($0.isActive ? 0 : 1, $0.organization) < ($1.isActive ? 0 : 1, $1.organization) }
            return .success((sorted, source))
        } catch let error as UsageError {
            return .failure(error)
        } catch {
            return .failure(.unreadableConfig)
        }
    }

    func safeStorageKey() throws -> Data {
        if let key { return key }
        if let keyFailure { throw keyFailure }
        do {
            let derived = SafeStorage.deriveKey(password: try readPassword())
            key = derived
            return derived
        } catch {
            keyFailure = error
            throw error
        }
    }

    static func token(_ selection: TokenSelection) -> Result<AccessToken, UsageError> {
        switch selection {
        case .usable(let token): .success(token)
        case .expired(let latest): .failure(.tokenExpired(latest))
        case .none: .failure(.notSignedIn)
        }
    }

    static func loginKey(_ profile: Profile, _ token: AccessToken) -> String {
        "\(profile.letter)|\(token.organization)|\(token.expiresAt.timeIntervalSince1970)"
    }

    static func failed(_ profile: Profile, _ error: UsageError) -> AccountSnapshot {
        AccountSnapshot(
            profile: profile, organization: nil, isActive: true, token: nil, account: nil,
            usage: .failure(error), fetchedAt: Date()
        )
    }

    static func usageResult(_ client: UsageClient, _ token: String) async -> Result<UsageReport, UsageError> {
        do {
            return .success(try await client.usage(token: token))
        } catch {
            return .failure(error as? UsageError ?? .unexpectedResponse)
        }
    }
}
