import Foundation
import Testing
@testable import UsageCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func sample(updatedAt: Date = now) -> SharedSnapshot {
    SharedSnapshot(updatedAt: updatedAt, copies: [
        .init(
            letter: "A", label: "Claude A", color: "#2F7BF5", plan: "Max 20x", inFront: true, state: .ok, readAt: now,
            windows: [
                .init(label: "5-hour", percent: 37, resetsAt: now.addingTimeInterval(7800)),
                .init(label: "Weekly · all models", percent: 62, resetsAt: now.addingTimeInterval(3 * 86400)),
            ]
        ),
        .init(letter: "B", label: "me@example.com", color: "#F5822F", plan: "Team", inFront: false, state: .rateLimited, readAt: now.addingTimeInterval(-720), windows: []),
    ])
}

private func temporaryFolder() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "notch-snapshot-\(UUID().uuidString)", directoryHint: .isDirectory)
}

@Suite struct SharedSnapshotTests {
    @Test func encodesVersionOneWithoutSecrets() throws {
        let text = String(decoding: try sample().encoded(), as: UTF8.self)
        #expect(text.contains("\"version\" : 1"))
        #expect(text.contains("\"updatedAt\" : \"2027-01-15T08:00:00Z\""))
        // The only fields there are; nothing that could hold a token, an email or a UUID.
        let root = try #require(try JSONSerialization.jsonObject(with: try sample().encoded()) as? [String: Any])
        #expect(Set(root.keys) == ["version", "updatedAt", "copies"])
        let copy = try #require((root["copies"] as? [[String: Any]])?.first)
        #expect(Set(copy.keys) == ["letter", "label", "color", "plan", "inFront", "state", "readAt", "windows"])
        #expect(!text.contains("@"))
        #expect(!text.contains("sk-ant"))
    }

    @Test func aLabelThatsAnEmailIsReplacedByTheProfileName() {
        #expect(sample().copies[1].label == "Claude B")
        #expect(sample().copies[0].label == "Claude A")
    }

    @Test func readsBackWhatItWrote() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "nested/usage.json")
        try sample().write(to: file)
        #expect(SharedSnapshot.read(from: file) == sample())
        // Written again over the first, in one go.
        try sample(updatedAt: now.addingTimeInterval(300)).write(to: file)
        #expect(SharedSnapshot.read(from: file)?.updatedAt == now.addingTimeInterval(300))
    }

    @Test func onlyThisUserCanReadIt() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "claude-multi-account/usage.json")
        try sample().write(to: file)
        let manager = FileManager.default
        let fileMode = try manager.attributesOfItem(atPath: file.path(percentEncoded: false))[.posixPermissions] as? Int
        let folderMode = try manager.attributesOfItem(atPath: file.deletingLastPathComponent().path(percentEncoded: false))[.posixPermissions] as? Int
        #expect(fileMode == 0o600)
        #expect(folderMode == 0o700)
        // No temporary file left behind.
        #expect(try manager.contentsOfDirectory(atPath: file.deletingLastPathComponent().path(percentEncoded: false)) == ["usage.json"])
    }

    @Test func aMissingOrForeignFileReadsAsNothing() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(SharedSnapshot.read(from: folder.appending(path: "usage.json")) == nil)
        #expect(SharedSnapshot.decode(Data("{ nope".utf8)) == nil)
        let later = try sample().encoded()
        let version2 = String(decoding: later, as: UTF8.self).replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 2")
        #expect(SharedSnapshot.decode(Data(version2.utf8)) == nil)
    }

    @Test func freshForFifteenMinutes() {
        let snapshot = sample()
        #expect(snapshot.isFresh(now: now.addingTimeInterval(15 * 60)))
        #expect(!snapshot.isFresh(now: now.addingTimeInterval(15 * 60 + 1)))
        #expect(snapshot.age(now: now.addingTimeInterval(20 * 60)) == 20 * 60)
    }

    @Test func statesFromTheLastRead() {
        let report = UsageReport(windows: [UsageWindow(label: "5-hour", percentUsed: 1, resetsAt: nil)], extraUsage: nil)
        let none = UsageReport(windows: [], extraUsage: nil)
        #expect(SharedSnapshot.State(error: nil, report: report) == .ok)
        #expect(SharedSnapshot.State(error: nil, report: none) == .noLimits)
        #expect(SharedSnapshot.State(error: nil, report: nil) == .unavailable)
        #expect(SharedSnapshot.State(error: .tokenExpired(now), report: report) == .stale)
        #expect(SharedSnapshot.State(error: .noLogin, report: nil) == .stale)
        #expect(SharedSnapshot.State(error: .rateLimited(retryAfter: nil), report: report) == .rateLimited)
        #expect(SharedSnapshot.State(error: .notSignedIn, report: nil) == .signedOut)
        #expect(SharedSnapshot.State(error: .keychain(-128), report: nil) == .keychain)
        #expect(SharedSnapshot.State(error: .network("offline"), report: report) == .unavailable)
        #expect(SharedSnapshot.State(error: .unexpectedResponse, report: nil) == .unavailable)
    }

    @Test func theEnvironmentCanPointElsewhere() {
        // Without the variable it's the cache folder; tests and the CLI's fixtures set it.
        if ProcessInfo.processInfo.environment[SharedSnapshot.environmentKey] == nil {
            #expect(SharedSnapshot.file.path(percentEncoded: false).hasSuffix("Library/Caches/claude-multi-account/usage.json"))
        }
    }
}
