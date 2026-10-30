import Foundation
import Security
import UsageCore

/// `--demo`: made-up accounts in every state a row can be in, read from nothing, so each
/// state can be looked at (`--demo --pin`) or rendered (`--demo --snapshot file.png`).
@MainActor
enum Demo {
    /// Where the demo keeps its settings, apart from the app's.
    static let defaultsSuite = "com.godzillaaa.claude-notch.demo"
    /// The demo's own Chrome switch, so flipping it leaves the relay alone.
    static let chromeAccess = ChromeAccess(folder: FileManager.default.temporaryDirectory.appending(path: defaultsSuite))

    static func fill(_ model: AccountsModel, now: Date = Date()) {
        func profile(_ letter: String) -> Profile {
            Profile(letter: letter, dataDirectory: URL(filePath: "/dev/null/Claude-\(letter)"))
        }
        func account(
            _ letter: String, _ organization: String?, active: Bool = true, plan: String? = nil, in team: String? = nil,
            _ windows: [UsageWindow]? = nil, readAgo: TimeInterval = 40, error: UsageError? = nil
        ) -> AccountsModel.Account {
            var account = AccountsModel.Account(profile: profile(letter), organization: organization)
            account.isActive = active
            account.email = organization == nil ? nil : "\(letter.lowercased())@example.com"
            account.plan = plan
            account.organizationLabel = plan == nil ? nil : team ?? "Personal"
            if let windows {
                account.report = UsageReport(windows: windows, extraUsage: nil)
                account.reportAt = now.addingTimeInterval(-readAgo)
            }
            account.error = error
            account.lastAttempt = now.addingTimeInterval(-40)
            account.nextPoll = now.addingTimeInterval(PollPlan.interval)
            return account
        }
        func window(_ label: String, _ percent: Double, resetsIn: TimeInterval?) -> UsageWindow {
            UsageWindow(label: label, percentUsed: percent, resetsAt: resetsIn.map { now.addingTimeInterval($0) })
        }
        let day: TimeInterval = 86400

        var rateLimited = account(
            "B", "b-personal", active: false, plan: "Max 20x",
            [window("5-hour", 0, resetsIn: nil), window("Weekly · all models", 71, resetsIn: 3 * day)],
            readAgo: 12 * 60, error: .rateLimited(retryAfter: nil)
        )
        rateLimited.rateLimits = 3
        rateLimited.nextPoll = now.addingTimeInterval(20 * 60)

        let accounts = [
            // OK.
            account("A", "a-personal", plan: "Max 20x", [
                window("5-hour", 37, resetsIn: 2 * 3600 + 10 * 60),
                window("Weekly · all models", 62, resetsIn: 3 * day),
                window("Weekly · Fable", 20, resetsIn: 3 * day),
            ]),
            // At a limit in the Team it works in, beside a rate-limited personal plan.
            account("B", "b-team", plan: "Team", in: "Acme", [
                window("5-hour", 92, resetsIn: 3600 + 5 * 60),
                window("Weekly · Fable", 100, resetsIn: 2 * day),
            ]),
            rateLimited,
            // Stale: the login expired, so the last numbers are greyed with their age.
            account(
                "C", "c-team", plan: "Team", in: "Acme", [window("5-hour", 55, resetsIn: 3600), window("Weekly · Fable", 30, resetsIn: day * 4)],
                readAgo: 3 * 3600, error: .tokenExpired(now.addingTimeInterval(-3 * 3600))
            ),
            // A plan with no limits.
            account("C", "c-enterprise", active: false, plan: "Enterprise", in: "Globex", []),
            // Not signed in.
            account("D", nil, error: .notSignedIn),
            // The endpoint changed shape: never guess numbers.
            account("E", "e-personal", plan: "Pro", error: .unexpectedResponse),
            // Claude says it's working in an organization it holds no login for yet.
            account("F", "f-team", error: .noLogin),
        ]
        model.show(
            profiles: ["A", "B", "C", "D", "E", "F"].map(profile), accounts: accounts,
            keychainProblem: .keychain(errSecAuthFailed)
        )
        // A used Chrome a moment ago: its row shows the globe for the rest of the minute.
        model.chrome.called("A", at: now.addingTimeInterval(-12))
    }

    /// A switch peek and then an alert soon after launch, to see both without waiting.
    static func peeks(_ controller: NotchController) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            controller.peek(Peek(letter: "B", kind: .switched))
            try? await Task.sleep(for: .seconds(3.5))
            let window = UsageWindow(label: "5-hour", percentUsed: 91, resetsAt: Date().addingTimeInterval(48 * 60))
            controller.peek(Peek(letter: "A", kind: .alert(.near(window))))
        }
    }
}
