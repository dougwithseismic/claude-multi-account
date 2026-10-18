import Foundation
import UsageCore

// claude-usage [--json] [--verbose] [--only B,C] [--signed-in]
// Prints each Claude profile's limits, read from that copy's own login.
// --signed-in only prints the letters of the copies that have a login, for install.sh.
// Exits 0 when at least one account's usage was read, 1 when none was, 2 on bad arguments.

let usageLine = "usage: claude-usage [--json] [--verbose] [--only A,B,…] [--signed-in]"

func badArguments(_ message: String) -> Never {
    FileHandle.standardError.write(Data("claude-usage: \(message)\n\(usageLine)\n".utf8))
    exit(2)
}

var json = false
var verbose = false
var only: Set<String>?
var signedIn = false
var arguments = CommandLine.arguments.dropFirst()
while let argument = arguments.popFirst() {
    switch argument {
    case "-h", "--help":
        print(usageLine)
        exit(0)
    case "--json":
        json = true
    case "-v", "--verbose":
        verbose = true
    case "--only":
        let letters = (arguments.popFirst() ?? "").uppercased().split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard !letters.isEmpty, letters.allSatisfy({ $0.count == 1 && $0.first!.isLetter }) else {
            badArguments("--only takes profile letters, like --only B,C")
        }
        only = Set(letters)
    case "--signed-in":
        signedIn = true
    default:
        badArguments("unknown argument \(argument)")
    }
}

var profiles = Profile.discover()
if let only { profiles = profiles.filter { only.contains($0.letter) } }
if signedIn {
    // From config.json alone: no Keychain, no network.
    print(profiles.filter { (try? ProfileConfig.read($0))?.encryptedTokenCache != nil }.map(\.letter).joined(separator: " "))
    exit(0)
}
guard !profiles.isEmpty else {
    let message = only == nil
        ? "No Claude profiles found in ~/Library/Application Support"
        : "No Claude profile matches --only \(only!.sorted().joined(separator: ","))"
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let reader = AccountReader()
if verbose {
    // Where each copy's organization in use came from, on stderr so --json stays clean.
    for read in await reader.logins(of: profiles) {
        let found = (try? read.logins.get())?.count ?? 0
        let source = read.activeSource.map { "in use from \($0.rawValue)" } ?? "\(read.logins)"
        FileHandle.standardError.write(Data("Claude \(read.profile.letter): \(found) organization(s), \(source)\n".utf8))
    }
}
let snapshots = await reader.snapshots(of: profiles)

if json {
    print(String(decoding: try JSONEncoder.pretty.encode(snapshots.map(JSONSnapshot.init)), as: UTF8.self))
} else {
    let now = Date()
    for (index, s) in snapshots.enumerated() {
        let sameCopy = snapshots.filter { $0.profile.letter == s.profile.letter }
        if index == 0 || snapshots[index - 1].profile.letter != s.profile.letter {
            if index > 0 { print() }
            print(Text.header(s))
        }
        if s.organization != nil { print("   " + Text.organization(s, among: sameCopy.count, now: now)) }
        switch s.usage {
        case .success(let report):
            let width = report.windows.map(\.label.count).max() ?? 0
            if report.windows.isEmpty { print("     No limits reported") }
            for w in report.windows {
                print("     " + Text.row(w, labelWidth: width, now: now))
            }
            if let extra = report.extraUsage {
                print("     " + Text.extra(extra, labelWidth: max(width, "Extra usage".count)))
            }
        case .failure(let error):
            print("     " + error.description)
        }
    }
}
exit(snapshots.contains { if case .success = $0.usage { true } else { false } } ? 0 : 1)

// MARK: - Text output

enum Text {
    /// Labels and colours from ~/.config/claude-multi-account/profiles.json, as in the notch.
    static let styles = ProfileStyle.load()
    static let tty = isatty(STDOUT_FILENO) != 0

    static func styled(_ s: String, _ code: String) -> String { tty ? "\u{1B}[\(code)m\(s)\u{1B}[0m" : s }

    static func header(_ s: AccountSnapshot) -> String {
        let style = ProfileStyle.of(s.profile.letter, in: styles)
        let colour = ProfileStyle.rgb(style.color).map { "38;2;\(Int($0.red * 255));\(Int($0.green * 255));\(Int($0.blue * 255))" }
        var parts = [styled(style.label, "1;" + (colour ?? "39"))]
        if let email = s.account?.email { parts.append(email) }
        return parts.joined(separator: "  ·  ")
    }

    /// "Team · Acme · in use   (login valid 29d more)". Which one is in use only matters
    /// when the copy is in more than one organization.
    static func organization(_ s: AccountSnapshot, among count: Int, now: Date) -> String {
        var line = styled(PlanName.label(plan: s.plan, organization: s.organizationLabel) ?? "Organization \(s.organization!.prefix(8))", "1")
        if count > 1 { line += s.isActive ? " · in use" : styled(" · not in use", "2") }
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

    static func duration(_ seconds: TimeInterval) -> String { UsageFormat.duration(seconds) }
}

// MARK: - JSON output

struct JSONSnapshot: Encodable {
    let letter: String
    let email: String?
    let organization: String?
    let organizationName: String?
    let active: Bool
    let plan: String?
    let subscriptionType: String?
    let loginExpiresAt: Date?
    let usage: UsageReport?
    let error: String?

    init(_ s: AccountSnapshot) {
        letter = s.profile.letter
        email = s.account?.email
        organization = s.organization
        organizationName = s.organizationLabel
        active = s.isActive
        plan = s.plan
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
