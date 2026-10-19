import Foundation

/// Which copy to switch to: the one with the most room in the organization it's working in.
/// From numbers already read, so asking costs nothing.
public enum BestCopy {
    /// Numbers older than this don't say enough about now to choose by.
    public static let freshFor: TimeInterval = 15 * 60

    /// One copy, in profile order: its organization in use's last good numbers and when
    /// they were read.
    public struct Candidate: Sendable, Equatable {
        public let letter: String
        public let report: UsageReport?
        public let readAt: Date?

        public init(letter: String, report: UsageReport?, readAt: Date?) {
            self.letter = letter
            self.report = report
            self.readAt = readAt
        }
    }

    public enum Choice: Sendable, Equatable {
        case copy(String)
        /// Every copy read lately is out, or none was read lately. `back` is the copy back
        /// first and when, if any copy is out with a known reset.
        case noRoom(back: Back?)
    }

    public struct Back: Sendable, Equatable {
        public let letter: String
        public let at: Date

        public init(letter: String, at: Date) {
            self.letter = letter
            self.at = at
        }
    }

    /// Among copies read fine in the last 15 minutes and not out of any window, the one
    /// whose fullest window (5-hour or weekly peak) is lowest; ties go to the earlier copy.
    /// A copy whose plan reports no windows is passed over: its room can't be told.
    public static func choose(_ candidates: [Candidate], now: Date) -> Choice {
        var best: (letter: String, fullest: Double)?
        for candidate in candidates {
            guard let fullest = fullest(candidate, now: now) else { continue }
            if best.map({ fullest < $0.fullest }) ?? true { best = (candidate.letter, fullest) }
        }
        if let best { return .copy(best.letter) }
        return .noRoom(back: firstBack(candidates, now: now))
    }

    /// How full a copy's fullest window is, 0–100, or nil when it can't be chosen: not read
    /// lately, nothing to go by, or out. A window whose reset has passed counts as empty.
    public static func fullest(_ candidate: Candidate, now: Date) -> Double? {
        guard let report = candidate.report, !report.windows.isEmpty, let readAt = candidate.readAt,
              now.timeIntervalSince(readAt) <= freshFor
        else { return nil }
        let current = UsageReport(windows: report.windows.map { window in
            let reset = window.resetsAt.map { $0 <= now } == true
            return UsageWindow(label: window.label, percentUsed: reset ? 0 : window.percentUsed, resetsAt: window.resetsAt)
        }, extraUsage: nil)
        guard !current.isOut else { return nil }
        return max(current.fiveHour?.percentUsed ?? 0, current.weeklyPeak?.percentUsed ?? 0)
    }

    /// The copy that's back first among those out, and when. Old numbers count here: a
    /// window only fills until it resets, so one that was out stays out until then.
    static func firstBack(_ candidates: [Candidate], now: Date) -> Back? {
        candidates.compactMap { candidate -> Back? in
            guard let at = candidate.report?.backAt, at > now else { return nil }
            return Back(letter: candidate.letter, at: at)
        }
        .min { $0.at < $1.at }
    }
}
