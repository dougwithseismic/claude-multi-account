import Foundation

/// `claude-usage --statusline`: one line for Claude Code's status line, from the snapshot
/// Claude Notch shares and the numbers Claude Code passes on stdin. No Keychain, no network.
///
///     Code 41·63  ▸A 37·62  B 92·✕  C 12·30
///
/// "Code" is the account that Claude Code session is signed in to ("Code B" when it runs on
/// ~/.claude-B, as `claude-b` does), then each copy: its letter in its colour, the 5-hour
/// window · the fullest weekly one, red from 90%, ✕ when used up. ▸ marks the copy in front.
/// Old numbers are dimmed.
public enum StatusLine {
    /// The session's own limits, from Claude Code's stdin.
    public struct Session: Equatable, Sendable {
        public var fiveHour: Double?
        public var sevenDay: Double?
        /// The copy whose Claude Code folder the session runs on, from `CLAUDE_CONFIG_DIR`.
        public var letter: String?

        public init(fiveHour: Double?, sevenDay: Double?, letter: String? = nil) {
            self.fiveHour = fiveHour
            self.sevenDay = sevenDay
            self.letter = letter
        }
    }

    /// "B" for a `CLAUDE_CONFIG_DIR` of `~/.claude-B` (or `.claude-b`), as `install.sh
    /// --claude-code` sets up; nil for anything else, including no folder, which is A's.
    public static func letter(configDir: String?) -> String? {
        guard let configDir, !configDir.isEmpty else { return nil }
        let name = URL(filePath: configDir).lastPathComponent
        guard name.count == ".claude-B".count, name.lowercased().hasPrefix(".claude-"),
              let letter = name.last.map({ String($0).uppercased() }), letter.range(of: "^[A-Z]$", options: .regularExpression) != nil
        else { return nil }
        return letter
    }

    /// `rate_limits.five_hour` and `rate_limits.seven_day` from Claude Code's stdin JSON, each
    /// with `used_percentage` (0–100) and `resets_at` (Unix seconds). Nil for anything else:
    /// no input, bad JSON, or no `rate_limits` (a plan without them, or before the session's
    /// first answer). Either window can be missing; one past its reset is empty again.
    public static func session(from data: Data, now: Date = Date()) -> Session? {
        guard !data.isEmpty, let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let limits = root["rate_limits"] as? [String: Any]
        else { return nil }
        func used(_ key: String) -> Double? {
            guard let window = limits[key] as? [String: Any], let percent = number(window["used_percentage"]) else { return nil }
            if let reset = number(window["resets_at"]), reset <= now.timeIntervalSince1970 { return 0 }
            return max(percent, 0)
        }
        let session = Session(fiveHour: used("five_hour"), sevenDay: used("seven_day"))
        return session.fiveHour == nil && session.sevenDay == nil ? nil : session
    }

    /// A JSON number, or a string holding one; never a boolean.
    static func number(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber where CFGetTypeID(number) != CFBooleanGetTypeID(): number.doubleValue
        case let string as String: Double(string)
        default: nil
        }
    }

    /// The line, without a newline. A missing snapshot or one older than 15 minutes gives a
    /// dim hint in place of the copies. Wider than `columns`, copies go from the right
    /// first; the session's segment is cut short only when it's all that's left.
    public static func render(
        snapshot: SharedSnapshot?, session: Session?, only: Set<String>? = nil, now: Date = Date(), columns: Int? = nil
    ) -> String {
        var pieces: [Piece] = []
        if let session {
            let colour = session.letter.flatMap { letter in snapshot?.copies.first { $0.letter == letter }?.color }
            pieces.append(segment(session, colour: colour))
        }
        if let snapshot {
            if snapshot.isFresh(now: now) {
                pieces += snapshot.copies.filter { only?.contains($0.letter) ?? true }.map { segment($0, now: now) }
            } else {
                pieces.append(Piece([Atom("usage \(UsageFormat.duration(snapshot.age(now: now))) old", dim)]))
            }
        } else {
            pieces.append(Piece([Atom("Claude Notch isn't running", dim)]))
        }
        return fit(pieces, columns: columns)
    }

    /// The line without its colours, as it reads.
    public static func plain(_ line: String) -> String {
        line.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
    }

    // MARK: Segments

    static let red = "38;2;255;69;58"
    static let accent = "38;2;217;119;87"
    static let dim = "2"
    static let bold = "1"

    /// Some text and its SGR codes.
    struct Atom {
        let text: String
        let codes: [String]

        init(_ text: String, _ codes: String...) {
            self.text = text
            self.codes = codes
        }

        init(_ text: String, codes: [String]) {
            self.text = text
            self.codes = codes
        }

        var styled: String { codes.isEmpty ? text : "\u{1B}[\(codes.joined(separator: ";"))m\(text)\u{1B}[0m" }
    }

    struct Piece {
        var atoms: [Atom]
        init(_ atoms: [Atom]) { self.atoms = atoms }
        var width: Int { atoms.reduce(0) { $0 + $1.text.count } }
        var styled: String { atoms.map(\.styled).joined() }

        /// Cut to `width` columns, ending in "…".
        func truncated(to width: Int) -> Piece {
            guard self.width > width else { return self }
            guard width > 1 else { return Piece(width == 1 ? [Atom("…", dim)] : []) }
            var left = width - 1
            var kept: [Atom] = []
            for atom in atoms where left > 0 {
                let text = String(atom.text.prefix(left))
                kept.append(Atom(text, codes: atom.codes))
                left -= text.count
            }
            return Piece(kept + [Atom("…", dim)])
        }
    }

    /// "Code 41·63", or "Code B 41·63" with B in its colour (`colour`, else the accent).
    static func segment(_ session: Session, colour: String? = nil) -> Piece {
        var atoms = [Atom("Code", bold, accent)]
        if let letter = session.letter {
            atoms += [Atom(" "), Atom(letter, codes: [bold, colour.map(UsageText.foreground) ?? accent])]
        }
        return Piece(atoms + [Atom(" ")] + figures(session.fiveHour, session.sevenDay, dimmed: false))
    }

    static func segment(_ copy: SharedSnapshot.Copy, now: Date) -> Piece {
        let colour = UsageText.foreground(copy.color)
        let fresh = copy.readAt.map { now.timeIntervalSince($0) <= SharedSnapshot.freshFor } ?? false
        let dimmed = !fresh || copy.state == .stale
        var atoms: [Atom] = []
        if copy.inFront { atoms.append(Atom("▸", codes: [colour] + (dimmed ? [dim] : []))) }
        atoms.append(Atom(copy.letter, codes: [bold, colour] + (dimmed ? [dim] : [])))
        atoms.append(Atom(" "))
        // A window whose reset has passed is empty, whatever it was at the last read.
        let report = UsageReport(windows: copy.report.windows.map { window in
            let reset = window.resetsAt.map { $0 <= now } == true
            return UsageWindow(label: window.label, percentUsed: reset ? 0 : window.percentUsed, resetsAt: window.resetsAt)
        }, extraUsage: nil)
        if report.windows.isEmpty {
            atoms.append(Atom("–", dim))
        } else {
            atoms += figures(report.fiveHour?.percentUsed, report.weeklyPeak?.percentUsed, dimmed: dimmed)
        }
        return Piece(atoms)
    }

    /// "37·62": the 5-hour window and the weekly one, each red from 90%, ✕ when used up,
    /// "–" when there's none.
    static func figures(_ fiveHour: Double?, _ weekly: Double?, dimmed: Bool) -> [Atom] {
        func figure(_ percent: Double?) -> Atom {
            let extra = dimmed ? [dim] : []
            guard let percent else { return Atom("–", dim) }
            if percent >= 100 { return Atom("✕", codes: [bold, red] + extra) }
            let text = String(min(Int(percent.rounded()), 99))
            return percent >= 90 ? Atom(text, codes: [red] + extra) : Atom(text, codes: extra)
        }
        return [figure(fiveHour), Atom("·", dim), figure(weekly)]
    }

    /// Joined by two spaces; too wide, pieces go from the right until one is left, which is
    /// then cut short.
    static func fit(_ pieces: [Piece], columns: Int?) -> String {
        var pieces = pieces
        func width() -> Int { pieces.reduce(0) { $0 + $1.width } + 2 * max(pieces.count - 1, 0) }
        if let columns {
            while pieces.count > 1, width() > columns { pieces.removeLast() }
            if let first = pieces.first, first.width > columns { pieces = [first.truncated(to: max(columns, 0))] }
        }
        return pieces.map(\.styled).joined(separator: "  ")
    }
}
