import Foundation
import UsageCore

/// The film's made-up copies. Nothing is read: like `--demo`, the model is filled by hand.
@MainActor
enum Footage {
    static let letters = ["A", "B", "C"]
    static let profiles = letters.map { Profile(letter: $0, dataDirectory: URL(filePath: "/dev/null/Claude-\($0)")) }

    static let hour: TimeInterval = 3600
    static let day: TimeInterval = 86400

    /// A copy's plan and login, and its windows as (label, percent used, seconds to reset).
    struct Copy {
        let letter: String
        let plan: String
        let team: String
        let email: String
        var windows: [(String, Double, TimeInterval?)]
    }

    /// A personal Max plan, a Team at work and a Pro plan on the side.
    static let base = [
        Copy(letter: "A", plan: "Max 20x", team: "Personal", email: "you@example.com", windows: [
            ("5-hour", 37, 2 * hour + 10 * 60 + 30),
            ("Weekly · all models", 62, 3 * day + 2 * hour),
            ("Weekly · Fable", 20, 3 * day + 2 * hour),
        ]),
        Copy(letter: "B", plan: "Team", team: "Acme", email: "you@acme.example", windows: [
            ("5-hour", 64, hour + 20 * 60 + 30),
            ("Weekly · Fable", 41, 2 * day + 5 * hour),
        ]),
        Copy(letter: "C", plan: "Pro", team: "Personal", email: "side@example.org", windows: [
            ("5-hour", 12, 4 * hour + 25 * 60 + 30),
            ("Weekly · all models", 28, 5 * day + hour),
        ]),
    ]

    /// Every window at 0%, so the rings fill from empty when the real numbers arrive.
    static var empty: [Copy] {
        base.map { copy in
            var copy = copy
            copy.windows = copy.windows.map { ($0.0, 0, $0.2) }
            return copy
        }
    }

    static func with(_ copies: [Copy], _ letter: String, fiveHour percent: Double, resetsIn: TimeInterval?) -> [Copy] {
        copies.map { copy in
            guard copy.letter == letter else { return copy }
            var copy = copy
            copy.windows[0] = ("5-hour", percent, resetsIn)
            return copy
        }
    }

    static func accounts(_ copies: [Copy], now: Date = Date()) -> [AccountsModel.Account] {
        copies.map { copy in
            var account = AccountsModel.Account(
                profile: profiles.first { $0.letter == copy.letter }!, organization: "\(copy.letter.lowercased())-org"
            )
            account.email = copy.email
            account.plan = copy.plan
            account.organizationLabel = copy.team
            account.report = UsageReport(
                windows: copy.windows.map { UsageWindow(label: $0.0, percentUsed: $0.1, resetsAt: $0.2.map { now.addingTimeInterval($0) }) },
                extraUsage: nil
            )
            account.reportAt = now
            account.lastAttempt = now
            account.nextPoll = now.addingTimeInterval(PollPlan.interval)
            return account
        }
    }

    /// What `AccountsModel.apply` would alert on going from `old` to `new`: the first change
    /// worth a peek in each copy's organization in use.
    static func alerts(from old: [AccountsModel.Account], to new: [AccountsModel.Account]) -> [(String, LimitAlert)] {
        new.compactMap { account in
            let before = old.first { $0.id == account.id }?.report
            guard account.isActive, let report = account.report, let alert = LimitAlert.between(before, report) else { return nil }
            return (account.letter, alert)
        }
    }
}
