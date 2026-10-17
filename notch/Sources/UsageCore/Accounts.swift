import Foundation

/// Everything known about one profile after a read: who it is, how long its
/// login lasts, and its usage or why there isn't any.
public struct AccountSnapshot: Sendable {
    public let profile: Profile
    public let token: AccessToken?
    public let account: AccountProfile?
    public let usage: Result<UsageReport, UsageError>
    public let fetchedAt: Date
}

/// Reads every profile's login and usage. The Keychain is read once per instance,
/// the key kept in memory only.
public actor AccountReader {
    let client: UsageClient
    let readPassword: @Sendable () throws -> Data
    var key: Data?
    /// A failed Keychain read, kept for the rest of one `snapshots` call so a refused
    /// prompt isn't shown again for every profile.
    var keyFailure: Error?

    public init(client: UsageClient = UsageClient()) {
        self.init(client: client, readPassword: SafeStorage.keychainPassword)
    }

    init(client: UsageClient, readPassword: @escaping @Sendable () throws -> Data) {
        self.client = client
        self.readPassword = readPassword
    }

    public func snapshots(of profiles: [Profile]) async -> [AccountSnapshot] {
        keyFailure = nil
        return await withTaskGroup(of: AccountSnapshot.self) { group in
            for profile in profiles {
                let token = self.token(for: profile)
                group.addTask { await Self.fetch(profile, token, client: self.client) }
            }
            var all: [AccountSnapshot] = []
            for await snapshot in group { all.append(snapshot) }
            return all.sorted { $0.profile.letter < $1.profile.letter }
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

    func token(for profile: Profile) -> Result<AccessToken, UsageError> {
        do {
            let config = try ProfileConfig.read(profile)
            guard let encrypted = config.encryptedTokenCache else { return .failure(.notSignedIn) }
            let decrypted = try SafeStorage.decrypt(base64: encrypted, key: try safeStorageKey())
            switch try TokenCache.select(decrypted: decrypted, accountUUID: config.accountUUID) {
            case .usable(let token): return .success(token)
            case .expired(let latest): return .failure(.tokenExpired(latest))
            case .none: return .failure(.notSignedIn)
            }
        } catch let error as UsageError {
            return .failure(error)
        } catch {
            return .failure(.unreadableConfig)
        }
    }

    static func fetch(_ profile: Profile, _ token: Result<AccessToken, UsageError>, client: UsageClient) async -> AccountSnapshot {
        let accessToken: AccessToken
        switch token {
        case .failure(let error):
            return AccountSnapshot(profile: profile, token: nil, account: nil, usage: .failure(error), fetchedAt: Date())
        case .success(let t):
            accessToken = t
        }
        async let usage = usageResult(client, accessToken.token)
        // The profile is for labels only; its failure never hides usage.
        async let account = try? client.profile(token: accessToken.token)
        return AccountSnapshot(
            profile: profile, token: accessToken, account: await account, usage: await usage, fetchedAt: Date()
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
