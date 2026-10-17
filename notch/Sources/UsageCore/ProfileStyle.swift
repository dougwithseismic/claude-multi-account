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
    public let label: String
    /// "#2F7BF5".
    public let color: String
    /// The key that switches to this copy with ⌥⌘, or nil for none.
    public let hotkey: String?

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

    /// The file's entries, or the defaults when it's missing or unreadable. Entries without
    /// a single capital letter are skipped; a missing label or colour gets a plain one.
    public static func load(from url: URL = file) -> [ProfileStyle] {
        guard let data = try? Data(contentsOf: url) else { return defaults }
        return parse(data) ?? defaults
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
