import Foundation

/// `claude-usage`'s rows, the same for a live read and for `--cached`.
public enum UsageText {
    /// "5-hour  ████░░░░░░   37%  resets in 2h 10m (Mon 15:40)".
    public static func row(_ w: UsageWindow, labelWidth: Int, now: Date, colour: Bool) -> String {
        let label = w.label.padding(toLength: labelWidth, withPad: " ", startingAt: 0)
        let percent = String(format: "%3.0f%%", w.percentUsed)
        var line = "\(label)  \(bar(w.percentUsed, colour: colour))  \(percent)"
        if let reset = w.resetsAt {
            line += "  resets in \(UsageFormat.duration(reset.timeIntervalSince(now))) (\(reset.formatted(.dateTime.weekday(.abbreviated).hour().minute())))"
        }
        return line
    }

    /// Ten blocks, green, yellow from 70%, red from 90%.
    public static func bar(_ percent: Double, width: Int = 10, colour: Bool) -> String {
        let filled = min(width, max(0, Int((percent / 100 * Double(width)).rounded())))
        let s = String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
        return styled(s, percent >= 90 ? "31" : percent >= 70 ? "33" : "32", colour: colour)
    }

    public static func styled(_ s: String, _ code: String, colour: Bool) -> String {
        colour ? "\u{1B}[\(code)m\(s)\u{1B}[0m" : s
    }

    /// A profile's "#2F7BF5" as a 24-bit foreground colour, "38;2;47;123;245"; the
    /// terminal's own colour when it isn't one.
    public static func foreground(_ hex: String) -> String {
        ProfileStyle.rgb(hex).map {
            "38;2;\(Int(($0.red * 255).rounded()));\(Int(($0.green * 255).rounded()));\(Int(($0.blue * 255).rounded()))"
        } ?? "39"
    }

    // MARK: --cached

    /// `claude-usage --cached`: each copy as a live read prints it, from what Claude Notch
    /// read last. Its name and plan rather than an email and an organization, which the
    /// snapshot never holds; then the same rows.
    public static func cached(_ copies: [SharedSnapshot.Copy], now: Date, colour: Bool) -> String {
        copies.map { copy in
            var lines = [styled(copy.label, "1;" + foreground(copy.color), colour: colour) + (copy.inFront ? "  ·  in front" : "")]
            if let plan = copy.plan { lines.append("   " + styled(plan, "1", colour: colour)) }
            if let message = message(copy.state) {
                var line = "     " + message
                if let readAt = copy.readAt, !copy.windows.isEmpty {
                    line += styled("  (numbers from \(ago(now.timeIntervalSince(readAt))))", "2", colour: colour)
                }
                lines.append(line)
            }
            let width = copy.windows.map(\.label.count).max() ?? 0
            for window in copy.report.windows {
                lines.append("     " + row(window, labelWidth: width, now: now, colour: colour))
            }
            return lines.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    /// Why a copy's numbers aren't new, worded as a live read words its errors.
    public static func message(_ state: SharedSnapshot.State) -> String? {
        switch state {
        case .ok: nil
        case .noLimits: "No limits reported"
        case .stale: "Login no longer valid; open this Claude to renew it"
        case .rateLimited: "Rate-limited; Claude Notch tries again later"
        case .signedOut: "Not signed in"
        case .keychain: "Claude Notch can't read the Keychain"
        case .unavailable: "Usage unavailable"
        }
    }

    /// "2m ago", "just now".
    public static func ago(_ seconds: TimeInterval) -> String {
        seconds < 60 ? "just now" : "\(UsageFormat.duration(seconds)) ago"
    }
}
