import Foundation

/// How far through its window a limit is, and when it runs out if it keeps going at the
/// rate it has so far. Worked out from one read: no history, no extra call.
public enum PaceProjection {
    /// Too early in a window, or too little used, to say anything about the rate.
    public static let minimumElapsed = 0.1
    public static let minimumUsed = 5.0

    /// How long a window lasts: 5 hours, or 7 days for the weekly ones. Nil for one this
    /// doesn't know.
    public static func windowLength(_ window: UsageWindow) -> TimeInterval? {
        if window.label == UsageReport.fiveHourLabel { return 5 * 3600 }
        return window.label.hasPrefix(UsageReport.weeklyPrefix) ? 7 * 86400 : nil
    }

    /// How far through its window a limit is, 0–1: where an even pace would have the bar.
    /// Nil when the window hasn't started or its length isn't known.
    public static func elapsedFraction(_ window: UsageWindow, now: Date) -> Double? {
        guard let reset = window.resetsAt, let length = windowLength(window) else { return nil }
        let left = reset.timeIntervalSince(now)
        guard left > 0, left <= length else { return nil }
        return 1 - left / length
    }

    /// When the window reaches 100% at the rate it's been used so far, if that's before it
    /// resets: 40% used an hour into a 5-hour window runs out 2h 30m after it started. Nil
    /// on or under an even pace, already at 100%, or before at least 10% of the window has
    /// passed and 5% is used.
    public static func runsOut(_ window: UsageWindow, now: Date) -> Date? {
        guard let reset = window.resetsAt, let length = windowLength(window),
              let elapsed = elapsedFraction(window, now: now)
        else { return nil }
        let used = window.percentUsed
        guard elapsed >= minimumElapsed, used >= minimumUsed, used < 100 else { return nil }
        let start = reset.addingTimeInterval(-length)
        let out = start.addingTimeInterval(elapsed * length * 100 / used)
        // A minute's grace, so an even pace doesn't flicker in and out of a projection.
        return out < reset.addingTimeInterval(-60) ? out : nil
    }
}
