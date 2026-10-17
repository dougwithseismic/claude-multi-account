import Foundation
import Observation
import UsageCore

/// What the panel and peek windows show, shared by the controller (which changes it,
/// animated) and the views (which draw it).
@MainActor @Observable
final class NotchState {
    enum Page {
        case usage, settings
    }

    /// The panel is open; closed, it's folded away behind the notch and its window is
    /// ordered out once it gets there.
    var isOpen = false
    var page = Page.usage
    /// ⌥ is held over the open panel: details show for as long as it is.
    var revealHeld = false
    /// The panel grows out of the peek showing when it opened, rather than the notch.
    var openedFromPeek = false
    /// `--demo`: the accounts are made up, and the footer says so.
    var isDemo = false

    var peek: Peek?
    var peekShown = false

    /// Geometry, set by the controller from the layout. In the panel's own coordinates
    /// (origin top-left): the notch and the peek, which the closed panel folds into.
    var notchInPanel = CGRect.zero
    var peekInPanel = CGRect.zero
    /// The peek's size, and the notch in its coordinates.
    var peekSize = CGSize.zero
    var notchInPeek = CGRect.zero

    /// Called when the panel's content changes size, so the window can follow.
    @ObservationIgnored var onResize: ((CGSize) -> Void)?

    func showsDetails(_ preferences: Preferences) -> Bool { preferences.showDetails || revealHeld }
}

/// A message under the notch for a few seconds.
struct Peek: Equatable {
    enum Kind: Equatable {
        /// A hotkey switched to this copy.
        case switched
        case alert(LimitAlert)
    }

    let letter: String
    let kind: Kind
    /// Two peeks with the same text are still two peeks: the second restarts the timer.
    let id = UUID()

    var duration: TimeInterval {
        if case .switched = kind { 1.8 } else { 5 }
    }
}

/// A window of the organization a copy works in crossing a line between two reads.
enum LimitAlert: Equatable {
    /// The 5-hour window passed 90%.
    case near(UsageWindow)
    /// A window reached 100%.
    case out(UsageWindow)
    /// A window that was at 100% reset.
    case back(UsageWindow)

    static let nearLine = 90.0

    var window: UsageWindow {
        switch self {
        case .near(let window), .out(let window), .back(let window): window
        }
    }

    /// The change most worth a peek between two reads, if any. The first read has nothing
    /// to compare with, so it never alerts.
    static func between(_ old: UsageReport?, _ new: UsageReport) -> LimitAlert? {
        guard let old else { return nil }
        var found: [LimitAlert] = []
        for window in new.windows {
            guard let before = old.windows.first(where: { $0.label == window.label })?.percentUsed else { continue }
            let after = window.percentUsed
            if after >= 100, before < 100 {
                found.append(.out(window))
            } else if before >= 100, after < 100 {
                found.append(.back(window))
            } else if window.label == "5-hour", after >= nearLine, before < nearLine {
                found.append(.near(window))
            }
        }
        return found.min { $0.rank < $1.rank }
    }

    private var rank: Int {
        switch self {
        case .out: 0
        case .near: 1
        case .back: 2
        }
    }
}
