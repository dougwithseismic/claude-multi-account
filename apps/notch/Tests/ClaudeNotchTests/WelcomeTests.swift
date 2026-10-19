import Foundation
import Security
import Testing
@testable import ClaudeNotch
@testable import UsageCore

// The welcome page's checklist, the ⌥⌘ keys and the wording 0.5 adds. `now` and `window`
// are WordingTests'.

private func profile(_ letter: String) -> Profile { Profile(letter: letter, dataDirectory: URL(filePath: "/tmp/Claude-\(letter)")) }

private func account(_ letter: String, _ organization: String?, plan: String? = nil, error: UsageError? = nil) -> AccountsModel.Account {
    var account = AccountsModel.Account(profile: profile(letter), organization: organization)
    account.plan = plan
    account.error = error
    account.lastAttempt = now
    return account
}

@Suite struct WelcomeChecklistTests {
    @MainActor @Test func eachCopySignedInOrNot() {
        let model = AccountsModel(reader: nil)
        model.show(
            profiles: ["A", "B", "C", "D"].map(profile),
            accounts: [
                account("A", "org-a", plan: "Max 20x"), account("B", nil, error: .notSignedIn),
                account("C", nil, error: .unreadableConfig),
            ]
        )
        let checklist = WelcomeChecklist(model)
        #expect(checklist.keychain == .allowed)
        #expect(checklist.copies == [
            .init(letter: "A", state: .signedIn(plan: "Max 20x")),
            .init(letter: "B", state: .signedOut),
            .init(letter: "C", state: .other("Usage unavailable")),
            .init(letter: "D", state: .other("Reading…")),
        ])
    }

    @MainActor @Test func theKeychainIsAllowedOnceALoginIsRead() {
        let model = AccountsModel(reader: nil)
        model.show(profiles: [profile("A")], accounts: [])
        #expect(WelcomeChecklist(model).keychain == .waiting)
        // Signed out everywhere: nothing has asked yet.
        model.show(profiles: [profile("A")], accounts: [account("A", nil, error: .notSignedIn)])
        #expect(WelcomeChecklist(model).keychain == .waiting)
        model.show(profiles: [profile("A")], accounts: [account("A", nil, error: .keychain(errSecAuthFailed))], keychainProblem: .keychain(errSecAuthFailed))
        #expect(WelcomeChecklist(model).keychain == .refused(.keychain(errSecAuthFailed)))
        #expect(WelcomeChecklist(model).copies == [.init(letter: "A", state: .other("Waiting for Keychain access"))])
    }

    @MainActor @Test func gotItIsRemembered() throws {
        let suite = "claude-notch-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(!Preferences(defaults: defaults).welcomeSeen)
        #expect(Preferences(defaults: defaults).mostRoomHotkey)
        Preferences(defaults: defaults).welcomeSeen = true
        #expect(Preferences(defaults: defaults).welcomeSeen)
    }
}

@Suite struct HotkeyPlanTests {
    private func described(_ plan: [(key: String, target: HotkeyPlan.Target)]) -> [String] {
        plan.map { key, target in
            switch target {
            case .copy(let letter): "\(key)→\(letter)"
            case .mostRoom: "\(key)→most room"
            }
        }
    }

    @Test func eachProfilesKeyThenZeroForTheMostRoom() {
        #expect(described(HotkeyPlan.bindings(ProfileStyle.defaults, mostRoom: true)) == ["1→A", "2→B", "3→C", "0→most room"])
        #expect(described(HotkeyPlan.bindings(ProfileStyle.defaults, mostRoom: false)) == ["1→A", "2→B", "3→C"])
    }

    @Test func aProfileWhoseKeyIsZeroKeepsIt() {
        let styles = ProfileStyle.defaults + [ProfileStyle(letter: "J", label: "Claude J", color: "#B04FD6", hotkey: "0")]
        #expect(described(HotkeyPlan.bindings(styles, mostRoom: true)) == ["1→A", "2→B", "3→C", "0→J"])
        #expect(HotkeyPlan.mostRoomKeyOwner(styles) == "J")
        #expect(HotkeyPlan.mostRoomKeyOwner(ProfileStyle.defaults) == nil)
    }
}

@Suite struct ReleaseFiveWordingTests {
    @Test func aProjectionSaysWhenByTheClock() {
        let calendar = Calendar.current
        let noon = calendar.startOfDay(for: now).addingTimeInterval(12 * 3600)
        let later = noon.addingTimeInterval(3 * 3600 + 40 * 60)
        #expect(paceText(later, now: noon) == "out ~\(later.formatted(.dateTime.hour().minute())) at this pace")
        let tomorrow = noon.addingTimeInterval(14 * 3600)
        #expect(paceText(tomorrow, now: noon) == "out ~tomorrow \(tomorrow.formatted(.dateTime.hour().minute())) at this pace")
    }

    @Test func noRoomSaysWhichCopyIsBackFirst() {
        let at = now.addingTimeInterval(41 * 60)
        #expect(backText(at, now: now) == "back in 41m · \(clockText(at, now: now))")
        let peek = Peek(letter: "B", kind: .noRoom(BestCopy.Back(letter: "B", at: at)))
        #expect(peek.duration == 3)
        #expect(Peek(letter: "B", kind: .switched).duration == 1.8)
    }
}
