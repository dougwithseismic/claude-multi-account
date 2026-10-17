import Foundation

/// When to read each account again: every 5 minutes, spread out so the calls don't land
/// together, and backing off when the usage endpoint answers 429.
public enum PollPlan {
    public static let interval: TimeInterval = 5 * 60
    /// Opening the panel re-reads any account last read longer ago than this.
    public static let freshEnough: TimeInterval = 60
    public static let maxBackoff: TimeInterval = 6 * 60 * 60

    /// How far to push back the account at `index` of `count` read together, so the
    /// next round of calls is spread across the interval.
    public static func stagger(index: Int, count: Int) -> TimeInterval {
        count > 1 ? interval * Double(index) / Double(count) : 0
    }

    /// When to try again after the `failures`th 429 in a row: 5, 10, 20 minutes … capped at
    /// 6 hours. A real `Retry-After` replaces that, kept between 1 minute and 6 hours.
    public static func retryAfterRateLimit(failures: Int, retryAfter: Date?, now: Date) -> Date {
        if let retryAfter {
            let wait = min(max(retryAfter.timeIntervalSince(now), freshEnough), maxBackoff)
            return now.addingTimeInterval(wait)
        }
        let doublings = Double(min(max(failures, 1) - 1, 16))
        return now.addingTimeInterval(min(interval * pow(2, doublings), maxBackoff))
    }
}

/// Short, human durations shared by the CLI and the app.
public enum UsageFormat {
    /// "2d 3h", "2h 10m", "4m", or "now".
    public static func duration(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "now" }
        let minutes = Int(seconds / 60)
        let (d, h, m) = (minutes / 1440, minutes % 1440 / 60, minutes % 60)
        if d > 0 { return h > 0 ? "\(d)d \(h)h" : "\(d)d" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
