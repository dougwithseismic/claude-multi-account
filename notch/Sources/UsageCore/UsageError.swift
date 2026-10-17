import Foundation

public enum UsageError: Error, Equatable, Sendable {
    case unreadableConfig
    case notSignedIn
    case keychainItemMissing
    case keychain(OSStatus)
    case unknownEncryption
    case unreadableTokenCache
    /// Every token has expired; that copy of Claude has to run to renew its own.
    case tokenExpired(Date)
    /// 401/403: the token was revoked or the copy signed out.
    case unauthorized
    case rateLimited(retryAfter: Date?)
    case http(Int)
    case unexpectedResponse
    case network(String)
}

extension UsageError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unreadableConfig: "Can't read this copy's config.json"
        case .notSignedIn: "Not signed in"
        case .keychainItemMissing: "No \"Claude Safe Storage\" item in the Keychain"
        case .keychain(let s):
            s == errSecUserCanceled || s == errSecAuthFailed
                ? "Keychain access was refused" : "Keychain error \(s)"
        case .unknownEncryption: "Claude's login is stored in a format this doesn't know"
        case .unreadableTokenCache: "Can't decrypt Claude's login"
        case .tokenExpired: "Login expired; open this Claude to renew it"
        case .unauthorized: "Login no longer valid; open this Claude to renew it"
        case .rateLimited(let until):
            until.map { "Rate-limited until \($0.formatted(date: .omitted, time: .shortened))" } ?? "Rate-limited"
        case .http(let code): "Usage request failed (HTTP \(code))"
        case .unexpectedResponse: "Usage unavailable (unexpected response)"
        case .network(let m): "Network error: \(m)"
        }
    }
}
