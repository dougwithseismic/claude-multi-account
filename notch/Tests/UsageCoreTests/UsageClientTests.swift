import Foundation
import Synchronization
import Testing
@testable import UsageCore

/// Answers from the bearer token itself (`<status>` or `<status>|<Retry-After>`, or
/// `redirect`), so tests running in parallel share no state and nothing leaves the machine.
final class StubProtocol: URLProtocol {
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: configuration)
    }()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let url = request.url!
        if url.host() == "elsewhere.example" { return respond(200, body: Self.usageBody) }
        guard request.value(forHTTPHeaderField: "anthropic-beta") == "oauth-2025-04-20",
              let auth = request.value(forHTTPHeaderField: "Authorization"), auth.hasPrefix("Bearer ")
        else { return respond(400) }
        let spec = auth.dropFirst("Bearer ".count).split(separator: "|", omittingEmptySubsequences: false)
        if spec.first == "redirect" {
            let response = HTTPURLResponse(
                url: url, statusCode: 302, httpVersion: "HTTP/1.1",
                headerFields: ["Location": "https://elsewhere.example/api/oauth/usage"]
            )!
            client?.urlProtocol(
                self, wasRedirectedTo: URLRequest(url: URL(string: "https://elsewhere.example/api/oauth/usage")!),
                redirectResponse: response
            )
            return respond(302, headers: ["Location": "https://elsewhere.example/api/oauth/usage"])
        }
        let status = Int(spec.first ?? "") ?? 500
        let headers = spec.count > 1 ? ["Retry-After": String(spec[1])] : [:]
        respond(status, headers: headers, body: url.path().hasSuffix("profile") ? Self.profileBody : Self.usageBody)
    }

    func respond(_ status: Int, headers: [String: String] = [:], body: String = "") {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    static let usageBody = #"{"five_hour":{"utilization":12,"resets_at":null}}"#
    static let profileBody = #"{"account":{"email":"stub@example.com"}}"#
}

@Suite struct UsageClientTests {
    let client = UsageClient(session: StubProtocol.session)

    func usageError(_ token: String) async -> UsageError? {
        do {
            _ = try await client.usage(token: token)
            return nil
        } catch {
            return error as? UsageError
        }
    }

    @Test func sendsTheHeadersAndDecodes() async throws {
        #expect(try await client.usage(token: "200").fiveHour?.percentUsed == 12)
        #expect(try await client.profile(token: "200").email == "stub@example.com")
        // Any 2xx is a success; the body decides.
        #expect(try await client.usage(token: "203").fiveHour?.percentUsed == 12)
    }

    @Test func mapsStatuses() async {
        #expect(await usageError("401") == .unauthorized)
        #expect(await usageError("403") == .unauthorized)
        #expect(await usageError("500") == .http(500))
        #expect(await usageError("429|0") == .rateLimited(retryAfter: nil))
        #expect(await usageError("429") == .rateLimited(retryAfter: nil))
        guard case .rateLimited(let until?) = await usageError("429|3600") else {
            Issue.record("expected a Retry-After date")
            return
        }
        #expect(abs(until.timeIntervalSinceNow - 3600) < 60)
    }

    @Test func neverFollowsARedirect() async {
        #expect(await usageError("redirect") == .http(302))
    }
}

@Suite struct AccountReaderTests {
    static let password = Data("fixture-password".utf8)
    static let me = "aaaaaaaa-0000-0000-0000-000000000001"

    /// A profile folder whose config.json holds `cache` encrypted with the fixture password.
    static func profile(_ letter: String, in root: URL, cache: [String: Any]?) throws -> Profile {
        let folder = root.appending(path: "Claude-\(letter)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var config: [String: Any] = ["lastKnownAccountUuid": me]
        if let cache {
            let plain = try JSONSerialization.data(withJSONObject: cache)
            config["oauth:tokenCacheV2"] = try SafeStorage.encrypt(plain, key: SafeStorage.deriveKey(password: password))
        }
        try JSONSerialization.data(withJSONObject: config).write(to: folder.appending(path: "config.json"))
        return Profile(letter: letter, dataDirectory: folder)
    }

    static func cache(token: String, expiresIn seconds: TimeInterval) -> [String: Any] {
        let key = "9d1c250a-e61b-44d9-88ed-5944d1962f5e:11111111-2222-3333-4444-555555555555:https://api.anthropic.com:user:inference user:profile"
        return [key: ["token": token, "refreshToken": "never-read", "expiresAt": (Date().timeIntervalSince1970 + seconds) * 1000]]
    }

    @Test func asksTheKeychainOnceWhenItIsRefused() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "reader-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let profiles = try ["B", "C", "D"].map { try Self.profile($0, in: root, cache: Self.cache(token: "200", expiresIn: 9000)) }
        let asks = Mutex(0)
        let reader = AccountReader(client: UsageClient(session: StubProtocol.session)) {
            asks.withLock { $0 += 1 }
            throw UsageError.keychain(errSecUserCanceled)
        }

        let snapshots = await reader.snapshots(of: profiles)
        #expect(snapshots.allSatisfy { $0.usage == .failure(.keychain(errSecUserCanceled)) })
        #expect(asks.withLock { $0 } == 1)
        // The next read asks again, so a retry after "Allow" works.
        _ = await reader.snapshots(of: profiles)
        #expect(asks.withLock { $0 } == 2)
    }

    @Test func readsEachProfilesState() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "reader-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let profiles = try [
            Self.profile("C", in: root, cache: Self.cache(token: "200", expiresIn: 9000)),
            Self.profile("B", in: root, cache: Self.cache(token: "200", expiresIn: -60)),
            Self.profile("D", in: root, cache: nil),
            Self.profile("E", in: root, cache: Self.cache(token: "401", expiresIn: 9000)),
        ]
        let reader = AccountReader(client: UsageClient(session: StubProtocol.session)) { Self.password }

        let snapshots = await reader.snapshots(of: profiles)
        #expect(snapshots.map(\.profile.letter) == ["B", "C", "D", "E"])
        guard case .failure(.tokenExpired) = snapshots[0].usage else { Issue.record("B: \(snapshots[0].usage)"); return }
        #expect(snapshots[1].usage.map(\.fiveHour?.percentUsed) == .success(12))
        #expect(snapshots[1].account?.email == "stub@example.com")
        #expect(snapshots[2].usage == .failure(.notSignedIn))
        #expect(snapshots[3].usage == .failure(.unauthorized))
        #expect(snapshots[3].account == nil)
    }
}
