import Foundation

/// Adds Claude Code's `statusLine` to its `settings.json`, or takes ours out again, by
/// editing the text where the setting goes: everything else in the file stays byte for
/// byte as it was. It never replaces a status line that's already set.
public enum StatusLineSetting {
    /// How often Claude Code re-runs the command while a session is idle, in seconds: the
    /// snapshot changes every few minutes whether or not anything happens in the session.
    public static let refreshInterval = 60

    public enum Added: Equatable, Sendable {
        /// The file's new text.
        case added(String)
        /// It already runs `claude-usage --statusline`.
        case alreadyOurs
        /// Another status line is set, and left alone: its JSON.
        case other(String)
        /// Not a JSON object, or laid out in a way this can't follow: left alone. Why.
        case unreadable(String)
    }

    /// The setting, as it's added: `{"type": "command", "command": …, "refreshInterval": 60}`
    /// over lines indented one `unit` past `indent`, or on one line.
    public static func entry(command: String, indent: String = "", unit: String = "  ", multiline: Bool = true) -> String {
        let fields = [
            "\"type\": \"command\"", "\"command\": \(quoted(command))", "\"refreshInterval\": \(refreshInterval)",
        ]
        guard multiline else { return "{ " + fields.joined(separator: ", ") + " }" }
        return "{\n" + fields.map { indent + unit + $0 }.joined(separator: ",\n") + "\n\(indent)}"
    }

    /// `text` with our status line added, or why not. Nil or blank text is a new file.
    public static func add(command: String, to text: String?) -> Added {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .added("{\n  \"statusLine\": \(entry(command: command, indent: "  "))\n}\n")
        }
        guard let root = object(text) else { return .unreadable("it isn't a JSON object") }
        if let existing = root["statusLine"] { return isOurs(existing) ? .alreadyOurs : .other(json(existing)) }
        let bytes = Array(text.utf8)
        // Foundation lets a trailing comma through; this doesn't.
        guard let layout = Layout(bytes) else {
            return .unreadable("it has something plain JSON doesn't, such as a trailing comma")
        }

        var edited: [UInt8]
        if let last = layout.members.last, let first = layout.members.first {
            let (indent, multiline) = indentation(before: first.start, in: bytes)
            let member = "\"statusLine\": " + entry(command: command, indent: indent, unit: indent.isEmpty ? "  " : indent, multiline: multiline)
            let insertion = multiline ? ",\n" + indent + member : ", " + member
            edited = Array(bytes[..<last.end]) + Array(insertion.utf8) + Array(bytes[last.end...])
        } else {
            // "{}", or only space inside.
            let member = "\n  \"statusLine\": " + entry(command: command, indent: "  ") + "\n"
            edited = Array(bytes[...layout.open]) + Array(member.utf8) + Array(bytes[layout.close...])
        }
        let result = String(decoding: edited, as: UTF8.self)
        // Everything that was there is still there, and the setting reads as ours.
        guard let after = object(result), let added = after["statusLine"], isOurs(added),
              NSDictionary(dictionary: after.filter { $0.key != "statusLine" }).isEqual(to: root)
        else { return .unreadable("the edit didn't read back as the same settings") }
        return .added(result)
    }

    /// `text` without our status line, or nil when it has none of ours (another one stays).
    public static func remove(from text: String) -> String? {
        guard let root = object(text), let existing = root["statusLine"], isOurs(existing) else { return nil }
        let bytes = Array(text.utf8)
        guard let layout = Layout(bytes), let k = layout.members.lastIndex(where: { $0.key == "statusLine" }) else { return nil }
        let members = layout.members
        var edited: [UInt8]
        if members.count == 1 {
            let between = bytes[(layout.open + 1)..<layout.close]
            edited = Array(bytes[...layout.open]) + (between.contains(0x0A) ? [0x0A] : []) + Array(bytes[layout.close...])
        } else if k > 0 {
            // From the end of the one before: its comma goes too.
            edited = Array(bytes[..<members[k - 1].end]) + Array(bytes[members[k].end...])
        } else {
            edited = Array(bytes[..<members[0].start]) + Array(bytes[members[1].start...])
        }
        let result = String(decoding: edited, as: UTF8.self)
        guard let after = object(result), after["statusLine"] == nil,
              NSDictionary(dictionary: after).isEqual(to: root.filter { $0.key != "statusLine" })
        else { return nil }
        return result
    }

    /// A status line that runs `claude-usage --statusline`, wherever it's installed.
    public static func isOurs(_ value: Any?) -> Bool {
        guard let command = (value as? [String: Any])?["command"] as? String else { return false }
        return command.contains("claude-usage") && command.contains("--statusline")
    }

    /// Writes `text` over the file in one go, keeping its permissions; through a symlink,
    /// the file it points at is written and the link stays.
    public static func write(_ text: String, to url: URL) throws {
        let target = url.resolvingSymlinksInPath()
        let folder = target.deletingLastPathComponent()
        let manager = FileManager.default
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let mode = (try? manager.attributesOfItem(atPath: target.path(percentEncoded: false))[.posixPermissions] as? Int) ?? 0o644
        let temporary = folder.appending(path: ".\(target.lastPathComponent).\(UUID().uuidString)")
        do {
            try Data(text.utf8).write(to: temporary)
            try manager.setAttributes([.posixPermissions: mode], ofItemAtPath: temporary.path(percentEncoded: false))
            guard rename(temporary.path(percentEncoded: false), target.path(percentEncoded: false)) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        } catch {
            try? manager.removeItem(at: temporary)
            throw error
        }
    }

    // MARK: Reading the text

    static func object(_ text: String) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any]
    }

    static func json(_ value: Any) -> String {
        let data = try? JSONSerialization.data(
            withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
        )
        return data.map { String(decoding: $0, as: UTF8.self) } ?? "\(value)"
    }

    static func quoted(_ string: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        return (try? encoder.encode(string)).map { String(decoding: $0, as: UTF8.self) } ?? "\"\""
    }

    /// The space before the first key on its line, and whether it's on a line of its own.
    static func indentation(before index: Int, in bytes: [UInt8]) -> (String, Bool) {
        var i = index
        while i > 0, bytes[i - 1] == 0x20 || bytes[i - 1] == 0x09 { i -= 1 }
        guard i > 0, bytes[i - 1] == 0x0A || bytes[i - 1] == 0x0D else { return ("", false) }
        return (String(decoding: bytes[i..<index], as: UTF8.self), true)
    }

    /// Where the top-level object and each of its members are in the file's bytes. Only for
    /// text that already parsed as a JSON object.
    struct Layout {
        struct Member {
            let key: String
            /// The key's opening quote.
            let start: Int
            /// Just past the value.
            let end: Int
        }

        private(set) var open = 0
        private(set) var close = 0
        private(set) var members: [Member] = []

        init?(_ bytes: [UInt8]) {
            var i = 0
            let n = bytes.count
            func skipSpace() {
                while i < n, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[i]) { i += 1 }
            }
            func skipString() -> Bool {
                guard i < n, bytes[i] == UInt8(ascii: "\"") else { return false }
                i += 1
                while i < n {
                    if bytes[i] == UInt8(ascii: "\\") { i += 2; continue }
                    if bytes[i] == UInt8(ascii: "\"") { i += 1; return true }
                    i += 1
                }
                return false
            }
            func skipValue() -> Bool {
                skipSpace()
                guard i < n else { return false }
                switch bytes[i] {
                case UInt8(ascii: "\""):
                    return skipString()
                case UInt8(ascii: "{"), UInt8(ascii: "["):
                    var depth = 0
                    while i < n {
                        switch bytes[i] {
                        case UInt8(ascii: "\""):
                            guard skipString() else { return false }
                            continue
                        case UInt8(ascii: "{"), UInt8(ascii: "["):
                            depth += 1
                        case UInt8(ascii: "}"), UInt8(ascii: "]"):
                            depth -= 1
                            if depth == 0 { i += 1; return true }
                        default:
                            break
                        }
                        i += 1
                    }
                    return false
                default:
                    let start = i
                    while i < n, !Array(",}] \t\r\n".utf8).contains(bytes[i]) { i += 1 }
                    return i > start
                }
            }

            // A byte order mark, then the object.
            if n >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF { i = 3 }
            skipSpace()
            guard i < n, bytes[i] == UInt8(ascii: "{") else { return nil }
            open = i
            i += 1
            skipSpace()
            if i < n, bytes[i] == UInt8(ascii: "}") {
                close = i
            } else {
                while true {
                    skipSpace()
                    let start = i
                    guard skipString(),
                          let key = (try? JSONSerialization.jsonObject(with: Data(bytes[start..<i]), options: .fragmentsAllowed)) as? String
                    else { return nil }
                    skipSpace()
                    guard i < n, bytes[i] == UInt8(ascii: ":") else { return nil }
                    i += 1
                    guard skipValue() else { return nil }
                    members.append(Member(key: key, start: start, end: i))
                    skipSpace()
                    guard i < n else { return nil }
                    if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
                    guard bytes[i] == UInt8(ascii: "}") else { return nil }
                    close = i
                    break
                }
            }
            i = close + 1
            skipSpace()
            guard i == n else { return nil }
        }
    }
}
