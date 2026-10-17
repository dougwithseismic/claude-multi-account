import Foundation

/// The two read-only calls Claude Code's `/usage` makes. Nothing here refreshes a token.
public struct UsageClient: Sendable {
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let profileURL = URL(string: "https://api.anthropic.com/api/oauth/profile")!
    /// `URLSession.shared` can write responses, and the requests with their Authorization
    /// header, to an on-disk cache; an ephemeral session keeps everything in memory.
    static let ephemeralSession = URLSession(configuration: .ephemeral)

    let session: URLSession

    public init(session: URLSession? = nil) {
        self.session = session ?? Self.ephemeralSession
    }

    public func usage(token: String) async throws -> UsageReport {
        try UsageDecoding.report(from: try await get(Self.usageURL, token: token))
    }

    public func profile(token: String) async throws -> AccountProfile {
        try UsageDecoding.profile(from: try await get(Self.profileURL, token: token))
    }

    func get(_ url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request, delegate: NoRedirects())
        } catch {
            throw UsageError.network(error.localizedDescription)
        }
        let http = response as? HTTPURLResponse
        switch http?.statusCode ?? 0 {
        case 200..<300: return data
        case 401, 403: throw UsageError.unauthorized
        case 429: throw UsageError.rateLimited(retryAfter: Self.retryAfter(http?.value(forHTTPHeaderField: "Retry-After")))
        case let code: throw UsageError.http(code)
        }
    }

    /// `Retry-After` in seconds or as an HTTP date; 0, a past date or missing means unknown.
    static func retryAfter(_ value: String?, now: Date = Date()) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if let seconds = TimeInterval(value) {
            // TimeInterval also parses "inf" and "nan".
            return seconds.isFinite && seconds > 0 ? now.addingTimeInterval(seconds) : nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: value), date > now else { return nil }
        return date
    }
}

/// Declines redirects, so the bearer token only ever goes to the URL it was meant for.
/// A declined redirect comes back as its 3xx response.
final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
