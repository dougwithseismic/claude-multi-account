import Foundation
import Observation
import UsageCore

/// Which copies have used Chrome through claude-chrome-relay in the last minute, from the
/// notification the relay posts after each call. A copy's row shows a globe until a minute
/// after its last call, while access is on.
@MainActor @Observable
final class ChromeUse {
    /// How long a row shows the mark after its copy's last call.
    static let markDuration: TimeInterval = 60

    /// Each copy's last call, kept until its minute is up.
    private(set) var lastCalls: [String: Date] = [:]
    @ObservationIgnored private var expiries: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var observer: NSObjectProtocol?

    /// Listens for the relay's calls.
    func start() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: ChromeAccess.usedNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let letter = note.object as? String else { return }
            MainActor.assumeIsolated { self?.called(letter) }
        }
    }

    /// `letter` called Chrome at `date`: its mark shows until a minute after, then goes.
    func called(_ letter: String, at date: Date = Date()) {
        lastCalls[letter] = date
        expiries[letter]?.cancel()
        let left = Self.markDuration - Date().timeIntervalSince(date)
        expiries[letter] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(left, 0) + 0.1))
            guard !Task.isCancelled else { return }
            self?.expire(now: Date())
        }
    }

    /// Forgets the calls whose minute is up.
    func expire(now: Date) {
        lastCalls = lastCalls.filter { Self.isRecent($0.value, now: now) }
    }

    /// Whether `letter`'s row shows the mark: within a minute of its last call, and never
    /// while access is off.
    func showsMark(_ letter: String, accessOn: Bool, now: Date) -> Bool {
        guard accessOn, let last = lastCalls[letter] else { return false }
        return Self.isRecent(last, now: now)
    }

    /// A call at `call` still marks its row at `now`. A row's `now` can be a little older
    /// than a call that has just come in, which counts as recent too.
    static func isRecent(_ call: Date, now: Date) -> Bool {
        now.timeIntervalSince(call) < markDuration
    }
}
