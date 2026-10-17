import SwiftUI
import UsageCore

/// Each profile's label, colour and hotkey, from `~/.config/claude-multi-account/profiles.json`
/// (the defaults when it's missing). Read once at launch: quit and reopen after editing it.
struct AccountStyle {
    let label: String
    let color: Color
    let hotkey: String?

    @MainActor static var styles = ProfileStyle.load()

    @MainActor static func of(_ letter: String) -> AccountStyle {
        let style = ProfileStyle.of(letter, in: styles)
        return AccountStyle(label: style.label, color: Color(hex: style.color), hotkey: style.hotkey)
    }

    static let limitRed = Color(hex: 0xFF453A)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255
        )
    }

    /// "#2F7BF5"; grey if it doesn't parse.
    init(hex: String) {
        let rgb = ProfileStyle.rgb(hex) ?? (0.7, 0.7, 0.7)
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
