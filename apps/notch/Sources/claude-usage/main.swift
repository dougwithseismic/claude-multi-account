import Foundation
import UsageCore

// claude-usage [--json] [--verbose] [--only B,C] [--signed-in]
// claude-usage --cached | --statusline | --best [--only B,C]
// Prints each Claude profile's limits, read from that copy's own login, or from what
// Claude Notch read last (the snapshot: no Keychain, no network). See help below.
// Exits 0 when at least one account's usage was read, 1 when none was, 2 on bad arguments.
//
// For install.sh only, not in the help: --add-statusline <settings.json> <command> and
// --remove-statusline <settings.json> edit Claude Code's settings.json.

let usageLine = """
usage: claude-usage [--json] [--verbose] [--only A,B,…] [--signed-in]
       claude-usage --cached [--json] [--only A,B,…]
       claude-usage --statusline [--only A,B,…]
       claude-usage --best [--only A,B,…]
"""

let help = """
\(usageLine)

Each copy of Claude's 5-hour and weekly limits, read with that copy's own login.

  --json         The same as JSON.
  --verbose      Also where each copy's organization in use came from, on stderr.
  --only A,B     Only these copies.
  --signed-in    Just the letters of the copies with a login, from their config.json.

From what Claude Notch read last, with no Keychain and no network:

  --cached       The same rows. Fails when Claude Notch hasn't read for 15 minutes.
  --statusline   One line for Claude Code's status line: each copy's letter, its
                 5-hour · weekly percentages, red from 90%, ✕ when used up, ▸ for the
                 copy in front. Led by "Code" and the session's own limits when Claude
                 Code passes them on stdin. Always exits 0.
  --best         The letter of the copy with the most room: the lowest fullest window
                 among those read in the last 15 minutes. Reads live when Claude Notch
                 hasn't. Exits 1 when no copy has room.

Claude Notch keeps its snapshot in ~/Library/Caches/claude-multi-account/usage.json;
$\(SharedSnapshot.environmentKey) points these at another file.
Exit status: 0 when a copy's usage was read, 1 when none was, 2 on bad arguments.
"""

func badArguments(_ message: String) -> Never {
    FileHandle.standardError.write(Data("claude-usage: \(message)\n\(usageLine)\n".utf8))
    exit(2)
}

func fail(_ message: String, status: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(status)
}

enum Mode: Equatable {
    case live, signedIn, cached, statusLine, best
    case addStatusLine(settings: String, command: String)
    case removeStatusLine(settings: String)
}

var json = false
var verbose = false
var only: Set<String>?
var mode = Mode.live
var arguments = CommandLine.arguments.dropFirst()

@MainActor func choose(_ new: Mode, _ flag: String) {
    guard mode == .live else { badArguments("\(flag) can't be combined with the other modes") }
    mode = new
}

while let argument = arguments.popFirst() {
    switch argument {
    case "-h", "--help":
        print(help)
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
    case "--signed-in": choose(.signedIn, argument)
    case "--cached": choose(.cached, argument)
    case "--statusline": choose(.statusLine, argument)
    case "--best": choose(.best, argument)
    case "--add-statusline":
        guard let settings = arguments.popFirst(), let command = arguments.popFirst() else {
            badArguments("--add-statusline takes settings.json's path and the command")
        }
        choose(.addStatusLine(settings: settings, command: command), argument)
    case "--remove-statusline":
        guard let settings = arguments.popFirst() else { badArguments("--remove-statusline takes settings.json's path") }
        choose(.removeStatusLine(settings: settings), argument)
    default:
        badArguments("unknown argument \(argument)")
    }
}

switch mode {
case .statusLine:
    let line = StatusLine.render(
        snapshot: SharedSnapshot.read(), session: StatusLine.session(from: Input.read()), only: only,
        columns: ProcessInfo.processInfo.environment["COLUMNS"].flatMap(Int.init).flatMap { $0 > 0 ? $0 : nil }
    )
    print(line)
    exit(0)
case .cached:
    Cached.run(only: only, json: json)
case .best:
    if let snapshot = SharedSnapshot.read(), snapshot.isFresh() {
        Best.print(BestCopy.choose(snapshot.candidates.filter { only?.contains($0.letter) ?? true }, now: Date()))
    }
    // Claude Notch hasn't read lately: read now.
    let profiles = Live.profiles(only: only, failIfNone: true)
    let snapshots = await AccountReader().snapshots(of: profiles)
    let candidates = profiles.map { profile in
        let mine = snapshots.filter { $0.profile.letter == profile.letter }
        let inUse = mine.first(where: \.isActive) ?? mine.first
        let report = inUse.flatMap { try? $0.usage.get() }
        return BestCopy.Candidate(letter: profile.letter, report: report, readAt: report == nil ? nil : inUse?.fetchedAt)
    }
    Best.print(BestCopy.choose(candidates, now: Date()))
case .addStatusLine(let path, let command):
    Settings.add(command: command, to: URL(filePath: path))
case .removeStatusLine(let path):
    Settings.remove(from: URL(filePath: path))
case .signedIn:
    // From config.json alone: no Keychain, no network.
    print(Live.profiles(only: only, failIfNone: false).filter { (try? ProfileConfig.read($0))?.encryptedTokenCache != nil }.map(\.letter).joined(separator: " "))
    exit(0)
case .live:
    break
}

let profiles = Live.profiles(only: only, failIfNone: true)
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
                print("     " + UsageText.row(w, labelWidth: width, now: now, colour: Text.tty))
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

// MARK: - Live reads

enum Live {
    /// Every profile, or those `--only` names; with none, says so and exits 1.
    static func profiles(only: Set<String>?, failIfNone: Bool) -> [Profile] {
        var profiles = Profile.discover()
        if let only { profiles = profiles.filter { only.contains($0.letter) } }
        guard profiles.isEmpty, failIfNone else { return profiles }
        fail(only == nil
            ? "No Claude profiles found in ~/Library/Application Support"
            : "No Claude profile matches --only \(only!.sorted().joined(separator: ","))")
    }
}

// MARK: - From the snapshot

enum Cached {
    static func run(only: Set<String>?, json: Bool) -> Never {
        let file = SharedSnapshot.file
        let shown = file.path(percentEncoded: false).replacingOccurrences(of: NSHomeDirectory(), with: "~")
        guard let data = try? Data(contentsOf: file) else {
            fail("No usage from Claude Notch yet: it writes \(shown) after each read. Is it running?")
        }
        guard let snapshot = SharedSnapshot.decode(data) else { fail("Can't read \(shown): not a snapshot this version knows") }
        let now = Date()
        guard snapshot.isFresh(now: now) else {
            fail("Claude Notch last read usage \(UsageText.ago(snapshot.age(now: now))), so these numbers are old. Is it running? claude-usage without --cached reads them now.")
        }
        let copies = snapshot.copies.filter { only?.contains($0.letter) ?? true }
        guard !copies.isEmpty else {
            fail(only == nil ? "Claude Notch found no copies of Claude" : "No copy matches --only \(only!.sorted().joined(separator: ","))")
        }
        if json {
            let filtered = SharedSnapshot(updatedAt: snapshot.updatedAt, copies: copies)
            print(String(decoding: (try? filtered.encoded()) ?? Data(), as: UTF8.self))
        } else {
            print(UsageText.cached(copies, now: now, colour: Text.tty))
            fflush(stdout)
            FileHandle.standardError.write(Data((UsageText.styled("Read by Claude Notch \(UsageText.ago(snapshot.age(now: now)))", "2", colour: isatty(STDERR_FILENO) != 0) + "\n").utf8))
        }
        exit(copies.contains { $0.readAt != nil } ? 0 : 1)
    }
}

enum Best {
    static func print(_ choice: BestCopy.Choice) -> Never {
        switch choice {
        case .copy(let letter):
            Swift.print(letter)
            exit(0)
        case .noRoom(let back):
            let now = Date()
            fail(back.map {
                "No copy has room. \($0.letter) is back first, in \(UsageFormat.duration($0.at.timeIntervalSince(now))) (\($0.at.formatted(.dateTime.weekday(.abbreviated).hour().minute())))."
            } ?? "No copy has room, or none was read in the last 15 minutes.")
        }
    }
}

/// Claude Code's JSON on stdin, for `--statusline`. Nothing when stdin is a terminal;
/// otherwise what arrives, as soon as it's a whole JSON object or the input ends, with a
/// first byte within 0.1 s, all of it within 0.5 s, and at most 1 MB: a status line must
/// never hang on its input.
enum Input {
    static func read() -> Data {
        guard isatty(STDIN_FILENO) == 0 else { return Data() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        let deadline = Date().addingTimeInterval(0.5)
        var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        while data.count < 1 << 20 {
            let wait = data.isEmpty ? 100 : Int32(max(0, deadline.timeIntervalSinceNow * 1000))
            guard wait > 0, poll(&descriptor, 1, wait) > 0 else { break }
            let count = Darwin.read(STDIN_FILENO, &buffer, buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
            if (try? JSONSerialization.jsonObject(with: data)) is [String: Any] { break }
        }
        return data
    }
}

/// `--add-statusline` and `--remove-statusline`, for install.sh: Claude Code's settings.json
/// gets our status line only when it has none, and loses only ours.
enum Settings {
    static func add(command: String, to url: URL) -> Never {
        let shown = url.path(percentEncoded: false).replacingOccurrences(of: NSHomeDirectory(), with: "~")
        let text = read(url, shown: shown)
        switch StatusLineSetting.add(command: command, to: text) {
        case .added(let new):
            do { try StatusLineSetting.write(new, to: url) } catch { fail("Couldn't write \(shown): \(error.localizedDescription)") }
            print("Added Claude Code's status line to \(shown): \(command)")
            exit(0)
        case .alreadyOurs:
            print("Claude Code's status line already runs claude-usage --statusline (\(shown)).")
            exit(0)
        case .other(let existing):
            print("""
            \(shown) already has a status line, so it's left as it is:

              "statusLine": \(existing.replacingOccurrences(of: "\n", with: "\n  "))

            To show the copies' usage there instead, set it to:

              "statusLine": \(StatusLineSetting.entry(command: command, indent: "  "))
            """)
            exit(3)
        case .unreadable(let why):
            fail("Left \(shown) alone: \(why). To add the status line by hand:\n\n  \"statusLine\": \(StatusLineSetting.entry(command: command, indent: "  "))")
        }
    }

    static func remove(from url: URL) -> Never {
        let shown = url.path(percentEncoded: false).replacingOccurrences(of: NSHomeDirectory(), with: "~")
        guard let text = read(url, shown: shown), let new = StatusLineSetting.remove(from: text) else { exit(0) }
        do { try StatusLineSetting.write(new, to: url) } catch { fail("Couldn't write \(shown): \(error.localizedDescription)") }
        print("Removed the status line from \(shown)")
        exit(0)
    }

    /// The file's text, nil when there's no file; one that can't be read stops here.
    static func read(_ url: URL, shown: String) -> String? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { fail("Can't read \(shown) as UTF-8 text; left it alone") }
        return text
    }
}

// MARK: - Text output

enum Text {
    /// Labels and colours from ~/.config/claude-multi-account/profiles.json, as in the notch.
    static let styles = ProfileStyle.load()
    static let tty = isatty(STDOUT_FILENO) != 0

    static func styled(_ s: String, _ code: String) -> String { UsageText.styled(s, code, colour: tty) }

    static func header(_ s: AccountSnapshot) -> String {
        let style = ProfileStyle.of(s.profile.letter, in: styles)
        var parts = [styled(style.label, "1;" + UsageText.foreground(style.color))]
        if let email = s.account?.email { parts.append(email) }
        return parts.joined(separator: "  ·  ")
    }

    /// "Team · Acme · in use   (login valid 29d more)". Which one is in use only matters
    /// when the copy is in more than one organization.
    static func organization(_ s: AccountSnapshot, among count: Int, now: Date) -> String {
        var line = styled(PlanName.label(plan: s.plan, organization: s.organizationLabel) ?? "Organization \(s.organization!.prefix(8))", "1")
        if count > 1 { line += s.isActive ? " · in use" : styled(" · not in use", "2") }
        if let expires = s.token?.expiresAt {
            line += styled("   (login valid \(UsageFormat.duration(expires.timeIntervalSince(now))) more)", "2")
        }
        return line
    }

    static func extra(_ e: ExtraUsage, labelWidth: Int) -> String {
        let label = "Extra usage".padding(toLength: labelWidth, withPad: " ", startingAt: 0)
        guard e.enabled else { return "\(label)  off" }
        // No utilization in the response means no bar, rather than a made-up 0%.
        var line = label
        if let percent = e.percentUsed {
            line += "  \(UsageText.bar(percent, colour: tty))  " + String(format: "%3.0f%%", percent)
        }
        if let spent = e.spent, let limit = e.monthlyLimit {
            line += String(format: "  %.2f of %.2f %@", spent, limit, e.currency ?? "")
        }
        return line == label ? "\(label)  on" : line
    }
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
