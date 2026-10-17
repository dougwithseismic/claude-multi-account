import Foundation
import Observation

/// The choices on the panel's settings page, kept in UserDefaults.
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

    @ObservationIgnored private let defaults: UserDefaults

    enum Key {
        static let showDetails = "showDetails"
        static let openOn = "openOn"
        static let limitAlerts = "limitAlerts"
        static let switchPeeks = "switchPeeks"
        static let haptics = "haptics"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showDetails = defaults.bool(forKey: Key.showDetails)
        openOn = defaults.string(forKey: Key.openOn).flatMap(OpenOn.init) ?? .hover
        limitAlerts = defaults.object(forKey: Key.limitAlerts) as? Bool ?? true
        switchPeeks = defaults.object(forKey: Key.switchPeeks) as? Bool ?? true
        haptics = defaults.object(forKey: Key.haptics) as? Bool ?? true
    }
}
