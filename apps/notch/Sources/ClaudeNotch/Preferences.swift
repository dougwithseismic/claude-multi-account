import Foundation
import Observation
import UsageCore

/// The choices on the panel's settings page, kept in UserDefaults; Chrome access is the
/// one kept in a file instead.
@MainActor @Observable
final class Preferences {
    enum OpenOn: String, CaseIterable {
        case hover, click
    }

    /// Emails and Team names in the rows. Off, a row shows its profile name and plan, so
    /// the panel can open in front of anyone.
    var showDetails: Bool { didSet { defaults.set(showDetails, forKey: Key.showDetails) } }
    var openOn: OpenOn { didSet { defaults.set(openOn.rawValue, forKey: Key.openOn) } }
    /// A short peek when a copy nears or hits a limit, or comes back from one.
    var limitAlerts: Bool { didSet { defaults.set(limitAlerts, forKey: Key.limitAlerts) } }
    /// A short peek naming the copy a hotkey switched to.
    var switchPeeks: Bool { didSet { defaults.set(switchPeeks, forKey: Key.switchPeeks) } }
    /// A tick on the trackpad as the panel opens.
    var haptics: Bool { didSet { defaults.set(haptics, forKey: Key.haptics) } }
    /// ⌥⌘0 switches to the copy with the most room.
    var mostRoomHotkey: Bool {
        didSet {
            defaults.set(mostRoomHotkey, forKey: Key.mostRoomHotkey)
            onHotkeysChange?()
        }
    }
    /// Got it was pressed on the welcome page; until then it opens by itself at launch.
    var welcomeSeen: Bool { didSet { defaults.set(welcomeSeen, forKey: Key.welcomeSeen) } }
    /// claude-chrome-relay may use Chrome, for every copy. Read from its file, which a shell
    /// can change too, so `rereadChromeAccess()` picks that up.
    private(set) var chromeAccess: Bool

    /// Called when a setting changes which hotkeys there are.
    @ObservationIgnored var onHotkeysChange: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let chrome: ChromeAccess

    enum Key {
        static let showDetails = "showDetails"
        static let openOn = "openOn"
        static let limitAlerts = "limitAlerts"
        static let switchPeeks = "switchPeeks"
        static let haptics = "haptics"
        static let mostRoomHotkey = "mostRoomHotkey"
        static let welcomeSeen = "welcomeSeen"
    }

    init(defaults: UserDefaults = .standard, chrome: ChromeAccess = ChromeAccess()) {
        self.defaults = defaults
        self.chrome = chrome
        showDetails = defaults.bool(forKey: Key.showDetails)
        openOn = defaults.string(forKey: Key.openOn).flatMap(OpenOn.init) ?? .hover
        limitAlerts = defaults.object(forKey: Key.limitAlerts) as? Bool ?? true
        switchPeeks = defaults.object(forKey: Key.switchPeeks) as? Bool ?? true
        haptics = defaults.object(forKey: Key.haptics) as? Bool ?? true
        mostRoomHotkey = defaults.object(forKey: Key.mostRoomHotkey) as? Bool ?? true
        welcomeSeen = defaults.bool(forKey: Key.welcomeSeen)
        chromeAccess = chrome.isOn
    }

    /// Turns Chrome access on or off for every copy; the switch then shows what the file says.
    func setChromeAccess(_ on: Bool) {
        do { try chrome.set(on) } catch { complain("couldn't turn Chrome access \(on ? "on" : "off"): \(error.localizedDescription)") }
        rereadChromeAccess()
    }

    /// Picks up a change made in a shell since the last look.
    func rereadChromeAccess() {
        let on = chrome.isOn
        if on != chromeAccess { chromeAccess = on }
    }
}
