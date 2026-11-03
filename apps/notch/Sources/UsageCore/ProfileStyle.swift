import Foundation

/// How a copy looks and which key switches to it. Read from
/// `~/.config/claude-multi-account/profiles.json`, so adding Claude D is one line there:
///
///     [
///       { "letter": "A", "label": "Claude A", "color": "#2F7BF5", "hotkey": "1" },
///       { "letter": "D", "label": "Claude D", "color": "#B04FD6", "hotkey": "4" }
///     ]
public struct ProfileStyle: Sendable, Equatable {
    public let letter: String
    public var label: String
    /// "#2F7BF5".
    public var color: String
    /// The key that switches to this copy with ⌥⌘, or nil for none.
    public var hotkey: String?

    public init(letter: String, label: String, color: String, hotkey: String?) {
        self.letter = letter
        self.label = label
        self.color = color
        self.hotkey = hotkey
    }

    public static var file: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/claude-multi-account/profiles.json")
    }

    public static let defaults = [
        ProfileStyle(letter: "A", label: "Claude A", color: "#2F7BF5", hotkey: "1"),
        ProfileStyle(letter: "B", label: "Claude B", color: "#F5822F", hotkey: "2"),
        ProfileStyle(letter: "C", label: "Claude C", color: "#2FB36B", hotkey: "3"),
    ]

    /// A new copy's colour, as install.sh picks it; grey after H.
    public static let palette = [
        "A": "#2F7BF5", "B": "#F5822F", "C": "#2FB36B", "D": "#B04FD6",
        "E": "#E5487F", "F": "#1FB5C1", "G": "#E3B52B", "H": "#E5484D",
    ]

    /// The ⌥⌘ keys a copy can have: 1 to 9, then 0 (which is otherwise the most room's).
    public static let keys = (1...9).map(String.init) + ["0"]

    /// The copy to add next: the first free letter after A, its colour, and its own number
    /// as its key (B is 2) or else the first free one, as install.sh does. Nil after Z.
    public static func next(after styles: [ProfileStyle]) -> ProfileStyle? {
        let used = Set(styles.map(\.letter))
        guard let letter = (66...90).lazy.map({ String(UnicodeScalar(UInt8($0))) }).first(where: { !used.contains($0) }) else {
            return nil
        }
        let taken = Set(styles.compactMap(\.hotkey))
        let own = String(Int(letter.unicodeScalars.first!.value) - 64)
        let hotkey = own.count == 1 && !taken.contains(own) ? own : (1...9).map(String.init).first { !taken.contains($0) }
        return ProfileStyle(letter: letter, label: "Claude \(letter)", color: palette[letter] ?? plain(letter).color, hotkey: hotkey)
    }

    /// The file's entries, or the defaults when it's missing or unreadable. Entries without
    /// a single capital letter are skipped; a missing label or colour gets a plain one.
    public static func load(from url: URL = file) -> [ProfileStyle] {
        guard let data = try? Data(contentsOf: url) else { return defaults }
        return parse(data) ?? defaults
    }

    /// The file's entries, or the defaults when there's no file. Nil when it's there but
    /// isn't a JSON list with a profile in it, so a reload after a typo can keep what's in
    /// use rather than fall back to A, B and C.
    public static func reload(from url: URL = file) -> [ProfileStyle]? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return defaults }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parse(data)
    }

    static func parse(_ data: Data) -> [ProfileStyle]? {
        struct Entry: Decodable {
            let letter: String?
            let label: String?
            let color: String?
            let hotkey: String?
        }
        guard let entries = try? JSONDecoder().decode([Lenient<Entry>].self, from: data) else { return nil }
        let styles = entries.compactMap(\.value).compactMap { entry -> ProfileStyle? in
            guard let letter = entry.letter, letter.count == 1, letter.first!.isASCII, letter.first!.isUppercase else { return nil }
            let fallback = plain(letter)
            return ProfileStyle(
                letter: letter, label: entry.label ?? fallback.label,
                color: entry.color.flatMap { rgb($0) == nil ? nil : $0 } ?? fallback.color,
                hotkey: entry.hotkey.flatMap { $0.count == 1 ? $0.uppercased() : nil }
            )
        }
        return styles.isEmpty ? nil : styles
    }

    /// `styles` as the file is written: one profile to a line, like the template in the repo.
    public static func template(_ styles: [ProfileStyle]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        func json(_ string: String) -> String {
            (try? encoder.encode(string)).map { String(decoding: $0, as: UTF8.self) } ?? "\"\""
        }
        let lines = styles.map { style in
            var fields = [("letter", style.letter), ("label", style.label), ("color", style.color)]
            if let hotkey = style.hotkey { fields.append(("hotkey", hotkey)) }
            return "  { \(fields.map { "\"\($0.0)\": \(json($0.1))" }.joined(separator: ", ")) }"
        }
        return "[\n\(lines.joined(separator: ",\n"))\n]\n"
    }

    /// The style for `letter` in `styles`, or a plain grey one.
    public static func of(_ letter: String, in styles: [ProfileStyle]) -> ProfileStyle {
        styles.first { $0.letter == letter } ?? plain(letter)
    }

    static func plain(_ letter: String) -> ProfileStyle {
        ProfileStyle(letter: letter, label: "Claude \(letter)", color: "#B3B3B3", hotkey: nil)
    }

    /// "#2F7BF5" or "2F7BF5" as 0–1 components.
    public static func rgb(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return (Double(value >> 16 & 0xFF) / 255, Double(value >> 8 & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    struct Lenient<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }
}
