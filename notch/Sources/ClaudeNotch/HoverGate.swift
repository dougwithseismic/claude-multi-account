import Foundation

/// Decides when the panel opens and closes from where the pointer is, sampled on a
/// timer: tracking areas are unreliable on non-activating panels that resize.
struct HoverGate {
    static let openDelay: TimeInterval = 0.08
    static let closeDelay: TimeInterval = 0.35

    private(set) var isOpen = false
    private var enteredAt: TimeInterval?
    private var leftAt: TimeInterval?
    private var waitForExit = false

    /// Feeds one sample; returns true when `isOpen` changed.
    /// - Parameters:
    ///   - inTrigger: the pointer is over the notch.
    ///   - inPanel: the pointer is over the open panel.
    ///   - buttonDown: a mouse button is held, so the user is dragging, not reaching for the notch.
    mutating func update(inTrigger: Bool, inPanel: Bool, buttonDown: Bool, now: TimeInterval) -> Bool {
        if isOpen {
            if inTrigger || inPanel {
                leftAt = nil
                return false
            }
            let left = leftAt ?? now
            leftAt = left
            guard now - left >= Self.closeDelay else { return false }
            close()
            return true
        }
        if waitForExit {
            if !inTrigger { waitForExit = false }
            return false
        }
        guard inTrigger, !buttonDown else {
            enteredAt = nil
            return false
        }
        let entered = enteredAt ?? now
        enteredAt = entered
        guard now - entered >= Self.openDelay else { return false }
        isOpen = true
        enteredAt = nil
        leftAt = nil
        return true
    }

    /// Closes at once, for example after a row was clicked. The pointer has to leave the
    /// notch and come back before it opens again.
    mutating func close() {
        waitForExit = isOpen
        isOpen = false
        enteredAt = nil
        leftAt = nil
    }
}
