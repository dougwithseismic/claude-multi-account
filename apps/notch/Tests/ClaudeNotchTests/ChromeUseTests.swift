import Foundation
import Testing
@testable import ClaudeNotch
@testable import UsageCore

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

@MainActor @Suite struct ChromeUseTests {
    @Test func aRowIsMarkedForAMinuteAfterItsCopysLastCall() {
        let use = ChromeUse()
        #expect(!use.showsMark("B", accessOn: true, now: t0))
        use.called("B", at: t0)
        #expect(use.showsMark("B", accessOn: true, now: t0))
        #expect(use.showsMark("B", accessOn: true, now: t0.addingTimeInterval(59)))
        #expect(!use.showsMark("B", accessOn: true, now: t0.addingTimeInterval(60)))
        #expect(!use.showsMark("A", accessOn: true, now: t0))
        // Another call starts the minute again.
        use.called("B", at: t0.addingTimeInterval(50))
        #expect(use.showsMark("B", accessOn: true, now: t0.addingTimeInterval(100)))
    }

    @Test func noMarkWhileAccessIsOff() {
        let use = ChromeUse()
        use.called("B", at: t0)
        #expect(!use.showsMark("B", accessOn: false, now: t0))
    }

    @Test func aCallNewerThanTheRowsClockStillShows() {
        // The panel's clock ticks every 20 seconds, so a call can land after it.
        let use = ChromeUse()
        use.called("C", at: t0.addingTimeInterval(15))
        #expect(use.showsMark("C", accessOn: true, now: t0))
    }

    @Test func expiringForgetsOnlyCallsWhoseMinuteIsUp() {
        let use = ChromeUse()
        use.called("A", at: t0)
        use.called("B", at: t0.addingTimeInterval(30))
        use.expire(now: t0.addingTimeInterval(61))
        #expect(use.lastCalls.keys.sorted() == ["B"])
        use.expire(now: t0.addingTimeInterval(91))
        #expect(use.lastCalls.isEmpty)
    }

    @Test func theMarkGoesByItself() async throws {
        let use = ChromeUse()
        // Called 59.8 seconds ago: it goes a little over 0.2 seconds from now.
        use.called("D", at: Date().addingTimeInterval(-ChromeUse.markDuration + 0.2))
        #expect(use.lastCalls["D"] != nil)
        try await Task.sleep(for: .seconds(0.6))
        #expect(use.lastCalls["D"] == nil)
    }

    @Test func theSwitchReadsAndWritesItsFile() throws {
        let suite = "claude-notch-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let folder = FileManager.default.temporaryDirectory.appending(path: "chrome-\(UUID())")
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }
        let access = ChromeAccess(folder: folder)
        let preferences = Preferences(defaults: defaults, chrome: access)
        #expect(preferences.chromeAccess)

        preferences.setChromeAccess(false)
        #expect(!preferences.chromeAccess)
        #expect(!access.isOn)
        #expect(!Preferences(defaults: defaults, chrome: access).chromeAccess)

        // Turned back on in a shell: the switch follows on its next look.
        try FileManager.default.removeItem(at: access.offFile)
        #expect(!preferences.chromeAccess)
        preferences.rereadChromeAccess()
        #expect(preferences.chromeAccess)
    }

    @Test func theDemoMarksACopy() {
        let model = AccountsModel(reader: nil)
        Demo.fill(model)
        #expect(model.chrome.showsMark("A", accessOn: true, now: Date()))
        #expect(!model.chrome.showsMark("B", accessOn: true, now: Date()))
    }
}
