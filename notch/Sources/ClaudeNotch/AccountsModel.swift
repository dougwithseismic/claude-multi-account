import AppKit
import Observation
import UsageCore

/// Every account's last known usage, and the polling that keeps it current.
@MainActor @Observable
final class AccountsModel {
    /// One organization's limits in one copy of Claude. A copy signed in to a Team and a
    /// personal plan has one of each; `isActive` is the one it's working in.
    struct Account: Identifiable {
        let profile: Profile
        /// Nil for a copy with no readable login at all.
        let organization: String?
        var id: String { "\(profile.letter)|\(organization ?? "")" }
        var letter: String { profile.letter }
        var isActive = true
        var email: String?
        /// "Max 20x", "Team".
        var plan: String?
        /// The Team's name, or "Personal".
        var organizationLabel: String?
        /// The last good numbers, kept through later failures and shown with their age.
        var report: UsageReport?
        var reportAt: Date?
        var error: UsageError?
        var lastAttempt: Date?
        var nextPoll = Date.distantPast
        var rateLimits = 0

        init(profile: Profile, organization: String?) {
            self.profile = profile
            self.organization = organization
        }
    }

    /// One copy of Claude and its accounts, the one in use first.
    struct Copy: Identifiable {
        let profile: Profile
        let accounts: [Account]
        var id: String { profile.letter }
        var active: Account? { accounts.first }
        var others: ArraySlice<Account> { accounts.dropFirst() }
    }

    private(set) var profiles: [Profile] = []
    private(set) var accounts: [Account] = []
    /// The Keychain refused (or lost) Claude's key: polling stops until the user retries,
    /// so a refused prompt isn't shown again every few minutes.
    private(set) var keychainProblem: UsageError?
    var paused = false
    /// The copy in front, or used last: where claude:// links go.
    var lastUsed: String?
    /// Called after each update, so the panel can resize to its content.
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private let reader: AccountReader?
    @ObservationIgnored private var polling = false
    @ObservationIgnored private var timer: Timer?

    var copies: [Copy] {
        profiles.map { profile in Copy(profile: profile, accounts: accounts.filter { $0.profile == profile }) }
    }

    /// Every account read at least once, for `--snapshot`.
    var isSettled: Bool {
        !profiles.isEmpty && copies.allSatisfy { !$0.accounts.isEmpty && $0.accounts.allSatisfy { $0.lastAttempt != nil } }
    }

    init(reader: AccountReader? = AccountReader()) {
        self.reader = reader
    }

    func start() {
        discover()
        let timer = Timer(timeInterval: 5, repeats: true) { _ in MainActor.assumeIsolated { self.pollDue() } }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        pollDue()
    }

    /// Picks up profiles added or removed since the last look, keeping what's known.
    func discover() {
        profiles = Profile.discover()
        accounts.removeAll { account in !profiles.contains(account.profile) }
    }

    /// Reads, together, every copy with an account that's due: its logins from disk, then
    /// the usage of each due account.
    func pollDue(now: Date = Date()) {
        guard let reader, !paused, keychainProblem == nil, !polling else { return }
        let due = profiles.filter { profile in
            let mine = accounts.filter { $0.profile == profile }
            return mine.isEmpty || mine.contains { $0.nextPoll <= now }
        }
        guard !due.isEmpty else { return }
        polling = true
        Task {
            let reads = await reader.logins(of: due)
            let at = Date()
            let toFetch = reads.flatMap { sync($0, now: at) }
            let snapshots = await withTaskGroup(of: (Int, AccountSnapshot).self) { group in
                for (index, login) in toFetch.enumerated() {
                    group.addTask { (index, await reader.snapshot(of: login)) }
                }
                var all: [(Int, AccountSnapshot)] = []
                for await result in group { all.append(result) }
                return all.sorted { $0.0 < $1.0 }.map(\.1)
            }
            apply(snapshots)
            polling = false
        }
    }

    /// Opening the panel re-reads accounts last read over a minute ago, except those
    /// backing off from a 429.
    func refreshIfStale(now: Date = Date()) {
        for i in accounts.indices where accounts[i].rateLimits == 0 {
            if now.timeIntervalSince(accounts[i].lastAttempt ?? .distantPast) > PollPlan.freshEnough {
                accounts[i].nextPoll = min(accounts[i].nextPoll, now)
            }
        }
        pollDue(now: now)
    }

    /// After waking, read everything not backing off.
    func wake(now: Date = Date()) {
        paused = false
        discover()
        for i in accounts.indices where accounts[i].rateLimits == 0 {
            accounts[i].nextPoll = min(accounts[i].nextPoll, now)
        }
        pollDue(now: now)
    }

    func retryKeychain() {
        keychainProblem = nil
        for i in accounts.indices { accounts[i].nextPoll = .distantPast }
        pollDue()
        onChange?()
    }

    /// Brings one copy's accounts in line with the logins it holds now, keeping what's known
    /// about each, and returns the logins due a read. A failure that may pass (an unreadable
    /// config.json mid-write, the Keychain) keeps the last numbers; signing out clears them.
    func sync(_ read: ProfileLogins, now: Date) -> [Login] {
        let existing = accounts.filter { $0.profile == read.profile }
        var updated: [Account] = []
        var due: [Login] = []
        switch read.logins {
        case .success(let logins):
            for login in logins {
                var account = existing.first { $0.organization == login.organization }
                    ?? Account(profile: read.profile, organization: login.organization)
                account.isActive = login.isActive
                if account.nextPoll <= now { due.append(login) }
                updated.append(account)
            }
        case .failure(let error):
            updated = error == .notSignedIn || existing.isEmpty
                ? [Account(profile: read.profile, organization: nil)] : existing
            for i in updated.indices {
                updated[i].error = error
                updated[i].lastAttempt = now
                updated[i].rateLimits = 0
                updated[i].nextPoll = now.addingTimeInterval(PollPlan.interval)
            }
            switch error {
            case .keychain, .keychainItemMissing: keychainProblem = error
            default: break
            }
        }
        accounts = (accounts.filter { $0.profile != read.profile } + updated).sorted(by: Self.ordered)
        return due
    }

    func apply(_ snapshots: [AccountSnapshot]) {
        for (index, snapshot) in snapshots.enumerated() {
            guard let i = accounts.firstIndex(where: {
                $0.profile == snapshot.profile && $0.organization == snapshot.organization
            }) else { continue }
            if snapshot.usage == .failure(.otherAccount) {
                accounts.remove(at: i)
                continue
            }
            var account = accounts[i]
            let at = snapshot.fetchedAt
            account.lastAttempt = at
            account.email = snapshot.account?.email ?? account.email
            account.plan = snapshot.plan ?? account.plan
            account.organizationLabel = snapshot.organizationLabel ?? account.organizationLabel
            // Accounts read together are pushed apart, so the next calls don't land at once.
            let next = at.addingTimeInterval(PollPlan.interval + PollPlan.stagger(index: index, count: snapshots.count))
            switch snapshot.usage {
            case .success(let report):
                account.report = report
                account.reportAt = at
                account.error = nil
                account.rateLimits = 0
                account.nextPoll = next
            case .failure(let error):
                account.error = error
                if case .rateLimited(let retryAfter) = error {
                    account.rateLimits += 1
                    account.nextPoll = PollPlan.retryAfterRateLimit(
                        failures: account.rateLimits, retryAfter: retryAfter, now: at
                    )
                } else {
                    account.rateLimits = 0
                    account.nextPoll = next
                }
            }
            accounts[i] = account
        }
        onChange?()
    }

    /// By letter, the organization in use first.
    static func ordered(_ a: Account, _ b: Account) -> Bool {
        (a.letter, a.isActive ? 0 : 1, a.organization ?? "") < (b.letter, b.isActive ? 0 : 1, b.organization ?? "")
    }

    /// Fills the model without reading anything, for `--demo`.
    func show(profiles: [Profile], accounts: [Account], keychainProblem: UsageError? = nil) {
        self.profiles = profiles
        self.accounts = accounts.sorted(by: Self.ordered)
        self.keychainProblem = keychainProblem
        onChange?()
    }
}
