import Foundation

/// Decides when the panel opens and closes from where the pointer is, sampled on a
/// timer: tracking areas are unreliable on non-activating panels that resize.
struct HoverGate {
    static let openDelay: TimeInterval = 0.08
    static let closeDelay: TimeInterval = 0.35
    /// Faster than this the pointer is passing over the notch on its way across the menu
    /// bar, not resting on it: points per second.
    static let restSpeed: CGFloat = 500

    /// Off, resting on the notch does nothing and only a click (`openNow`) opens it.
    var hoverOpens = true
    private(set) var isOpen = false
    private var enteredAt: TimeInterval?
    private var leftAt: TimeInterval?
    private var waitForExit = false
    private var last: (pointer: CGPoint, at: TimeInterval)?

    /// Feeds one sample; returns true when `isOpen` changed.
    /// - Parameters:
    ///   - inTrigger: the pointer is over the notch.
    ///   - inPanel: the pointer is over the open panel.
    ///   - buttonDown: a mouse button is held, so the user is dragging, not reaching for the notch.
    ///   - pointer: where the pointer is, to tell resting from passing through.
    mutating func update(
        inTrigger: Bool, inPanel: Bool, buttonDown: Bool, now: TimeInterval, pointer: CGPoint = .zero
    ) -> Bool {
        let speed = last.map { last in
            now > last.at ? hypot(pointer.x - last.pointer.x, pointer.y - last.pointer.y) / (now - last.at) : 0
        } ?? 0
        last = (pointer, now)

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
        guard inTrigger, !buttonDown, hoverOpens else {
            enteredAt = nil
            return false
        }
        // The rest starts once the pointer slows down.
        if speed > Self.restSpeed { enteredAt = now }
        let entered = enteredAt ?? now
        enteredAt = entered
        guard now - entered >= Self.openDelay else { return false }
        isOpen = true
        enteredAt = nil
        leftAt = nil
        return true
    }

    /// Opens at once, for a click on the notch. Returns true when it wasn't open.
    mutating func openNow() -> Bool {
        guard !isOpen else { return false }
        isOpen = true
        waitForExit = false
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

/// Holding ⌥ over the open panel shows details: ⌥ on its own, once it's been held a moment.
/// ⌥ is also how the ⌥⌘ hotkeys start, and pressing one shouldn't flash the emails.
struct OptionReveal {
    static let holdDelay: TimeInterval = 0.15

    private var since: TimeInterval?

    /// Feeds one sample of the modifier keys; returns whether details show.
    /// - Parameters:
    ///   - option: ⌥ is down.
    ///   - others: ⌘, ⌃ or ⇧ is down too.
    mutating func update(option: Bool, others: Bool, now: TimeInterval) -> Bool {
        guard option, !others else {
            since = nil
            return false
        }
        let start = since ?? now
        since = start
        return now - start >= Self.holdDelay
    }
}
