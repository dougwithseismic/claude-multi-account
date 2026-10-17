import Foundation
import UsageCore

// claude-usage [--json] [--only B,C]
// Prints each Claude profile's limits, read from that copy's own login.
// Exits 0 when at least one account's usage was read, 1 when none was, 2 on bad arguments.

let usageLine = "usage: claude-usage [--json] [--only A,B,…]"

func badArguments(_ message: String) -> Never {
    FileHandle.standardError.write(Data("claude-usage: \(message)\n\(usageLine)\n".utf8))
    exit(2)
}

var json = false
var only: Set<String>?
var arguments = CommandLine.arguments.dropFirst()
while let argument = arguments.popFirst() {
    switch argument {
    case "-h", "--help":
        print(usageLine)
        exit(0)
    case "--json":
        json = true
    case "--only":
        let letters = (arguments.popFirst() ?? "").uppercased().split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard !letters.isEmpty, letters.allSatisfy({ $0.count == 1 && $0.first!.isLetter }) else {
            badArguments("--only takes profile letters, like --only B,C")
        }
        only = Set(letters)
    default:
        badArguments("unknown argument \(argument)")
    }
}

var profiles = Profile.discover()
if let only { profiles = profiles.filter { only.contains($0.letter) } }
guard !profiles.isEmpty else {
    let message = only == nil
        ? "No Claude profiles found in ~/Library/Application Support"
        : "No Claude profile matches --only \(only!.sorted().joined(separator: ","))"
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let snapshots = await AccountReader().snapshots(of: profiles)

if json {
    print(String(decoding: try JSONEncoder.pretty.encode(snapshots.map(JSONSnapshot.init)), as: UTF8.self))
} else {
    let now = Date()
    for (index, s) in snapshots.enumerated() {
        if index > 0 { print() }
        print(Text.header(s, now: now))
        switch s.usage {
        case .success(let report):
            let width = report.windows.map(\.label.count).max() ?? 0
            for w in report.windows {
                print("   " + Text.row(w, labelWidth: width, now: now))
            }
            if let extra = report.extraUsage {
                print("   " + Text.extra(extra, labelWidth: width))
            }
        case .failure(let error):
            print("   " + error.description)
        }
    }
}
exit(snapshots.contains { if case .success = $0.usage { true } else { false } } ? 0 : 1)

// MARK: - Text output

enum Text {
    static let colours = ["A": "38;5;33", "B": "38;5;208", "C": "38;5;35"]
    static let tty = isatty(STDOUT_FILENO) != 0

    static func styled(_ s: String, _ code: String) -> String { tty ? "\u{1B}[\(code)m\(s)\u{1B}[0m" : s }

    static func header(_ s: AccountSnapshot, now: Date) -> String {
        var parts = [styled("Claude \(s.profile.letter)", "1;" + (colours[s.profile.letter] ?? "39"))]
        if let email = s.account?.email { parts.append(email) }
        if let plan = s.token?.subscriptionType { parts.append(plan.capitalized) }
        var line = parts.joined(separator: "  ·  ")
        if let expires = s.token?.expiresAt {
            line += styled("   (login valid \(duration(expires.timeIntervalSince(now))) more)", "2")
        }
        return line
    }

    static func row(_ w: UsageWindow, labelWidth: Int, now: Date) -> String {
        let label = w.label.padding(toLength: labelWidth, withPad: " ", startingAt: 0)
        let percent = String(format: "%3.0f%%", w.percentUsed)
        var line = "\(label)  \(bar(w.percentUsed))  \(percent)"
        if let reset = w.resetsAt {
            line += "  resets in \(duration(reset.timeIntervalSince(now))) (\(reset.formatted(.dateTime.weekday(.abbreviated).hour().minute())))"
        }
        return line
    }

    static func extra(_ e: ExtraUsage, labelWidth: Int) -> String {
        let label = "Extra usage".padding(toLength: labelWidth, withPad: " ", startingAt: 0)
        guard e.enabled else { return "\(label)  off" }
        // No utilization in the response means no bar, rather than a made-up 0%.
        var line = label
        if let percent = e.percentUsed {
            line += "  \(bar(percent))  " + String(format: "%3.0f%%", percent)
        }
        if let spent = e.spent, let limit = e.monthlyLimit {
            line += String(format: "  %.2f of %.2f %@", spent, limit, e.currency ?? "")
        }
        return line == label ? "\(label)  on" : line
    }

    static func bar(_ percent: Double, width: Int = 10) -> String {
        let filled = min(width, max(0, Int((percent / 100 * Double(width)).rounded())))
        let s = String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
        return styled(s, percent >= 90 ? "31" : percent >= 70 ? "33" : "32")
    }

    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "now" }
        let minutes = Int(seconds / 60)
        let (d, h, m) = (minutes / 1440, minutes % 1440 / 60, minutes % 60)
        if d > 0 { return h > 0 ? "\(d)d \(h)h" : "\(d)d" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - JSON output

struct JSONSnapshot: Encodable {
    let letter: String
    let email: String?
    let subscriptionType: String?
    let loginExpiresAt: Date?
    let usage: UsageReport?
    let error: String?

    init(_ s: AccountSnapshot) {
        letter = s.profile.letter
        email = s.account?.email
        subscriptionType = s.token?.subscriptionType
        loginExpiresAt = s.token?.expiresAt
        switch s.usage {
        case .success(let r): usage = r; error = nil
        case .failure(let e): usage = nil; error = e.description
        }
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }
}
