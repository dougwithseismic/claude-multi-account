import CoreGraphics
import Foundation
import Testing
@testable import ClaudeNotch

/// `#expect` can't call a mutating method on a local, so samples go through this.
private func feed(_ gate: inout HoverGate, _ inTrigger: Bool, _ inPanel: Bool, _ buttonDown: Bool, _ now: Double) -> Bool {
    gate.update(inTrigger: inTrigger, inPanel: inPanel, buttonDown: buttonDown, now: now)
}

/// A sample with the pointer somewhere, over the notch or not.
private func move(_ gate: inout HoverGate, _ inTrigger: Bool, _ now: Double, _ x: Double, _ y: Double) -> Bool {
    gate.update(inTrigger: inTrigger, inPanel: false, buttonDown: false, now: now, pointer: CGPoint(x: x, y: y))
}

private func click(_ gate: inout HoverGate) -> Bool { gate.openNow() }

@Test func opensOnlyAfterResting() {
    var gate = HoverGate()
    #expect(!feed(&gate, true, false, false, 10))
    #expect(!feed(&gate, true, false, false, 10.05))
    #expect(feed(&gate, true, false, false, 10.1))
    #expect(gate.isOpen)
}

@Test func passingThroughDoesNotOpen() {
    var gate = HoverGate()
    _ = feed(&gate, true, false, false, 10)
    _ = feed(&gate, false, false, false, 10.05)
    // The rest starts again from here.
    #expect(!feed(&gate, true, false, false, 10.1))
    #expect(!gate.isOpen)
}

@Test func neverOpensWhileDragging() {
    var gate = HoverGate()
    for t in stride(from: 10.0, to: 11, by: 0.05) {
        _ = feed(&gate, true, false, true, t)
    }
    #expect(!gate.isOpen)
}

@Test func staysOpenOverThePanelAndClosesAfterLeaving() {
    var gate = HoverGate()
    _ = feed(&gate, true, false, false, 0)
    _ = feed(&gate, true, false, false, 0.1)
    #expect(!feed(&gate, false, true, false, 5))
    #expect(!feed(&gate, false, false, false, 6))
    #expect(!feed(&gate, false, false, false, 6.3))
    #expect(feed(&gate, false, false, false, 6.36))
    #expect(!gate.isOpen)
}

@Test func comingBackBeforeTheCloseDelayKeepsItOpen() {
    var gate = HoverGate()
    _ = feed(&gate, true, false, false, 0)
    _ = feed(&gate, true, false, false, 0.1)
    _ = feed(&gate, false, false, false, 1)
    _ = feed(&gate, false, true, false, 1.2)
    #expect(!feed(&gate, false, false, false, 1.5))
    #expect(gate.isOpen)
}

@Test func afterClosingByHandThePointerHasToLeaveFirst() {
    var gate = HoverGate()
    _ = feed(&gate, true, false, false, 0)
    _ = feed(&gate, true, false, false, 0.1)
    gate.close()
    #expect(!feed(&gate, true, false, false, 1))
    #expect(!feed(&gate, true, false, false, 2))
    _ = feed(&gate, false, false, false, 3)
    _ = feed(&gate, true, false, false, 4)
    #expect(feed(&gate, true, false, false, 4.1))
}

@Test func crossingTheNotchOnTheWayAcrossTheMenuBarDoesNotOpen() {
    var gate = HoverGate()
    // 1000 points a second, left to right through the cutout.
    for (i, x) in stride(from: 670.0, through: 840, by: 50).enumerated() {
        #expect(!move(&gate, true, 10 + 0.05 * Double(i), x, 970))
    }
    #expect(!gate.isOpen)
}

@Test func flungToTheTopThenRestingOpens() {
    var gate = HoverGate()
    _ = move(&gate, false, 10, 750, 700)
    // Arrives fast, then stops: the rest counts from the stop.
    #expect(!move(&gate, true, 10.05, 752, 975))
    #expect(!move(&gate, true, 10.1, 752, 975))
    #expect(move(&gate, true, 10.15, 752, 975))
}

@Test func setToClickRestingDoesNothingAndAClickOpens() {
    var gate = HoverGate()
    gate.hoverOpens = false
    for t in stride(from: 10.0, to: 11, by: 0.05) {
        _ = feed(&gate, true, false, false, t)
    }
    #expect(!gate.isOpen)
    #expect(click(&gate))
    #expect(!click(&gate))
    // Open, it closes like any other once the pointer has gone.
    _ = feed(&gate, false, false, false, 12)
    #expect(feed(&gate, false, false, false, 12.4))
}

private func keys(_ reveal: inout OptionReveal, option: Bool, others: Bool = false, _ now: Double) -> Bool {
    reveal.update(option: option, others: others, now: now)
}

@Test func holdingOptionAloneRevealsAfterAMoment() {
    var reveal = OptionReveal()
    #expect(!keys(&reveal, option: true, 10))
    #expect(!keys(&reveal, option: true, 10.1))
    #expect(keys(&reveal, option: true, 10.15))
    // Let go: gone at once.
    #expect(!keys(&reveal, option: false, 10.2))
}

@Test func aHotkeyOnItsWayNeverReveals() {
    var reveal = OptionReveal()
    // ⌥ first, then ⌘ a beat later, as in ⌥⌘2.
    #expect(!keys(&reveal, option: true, 10))
    #expect(!keys(&reveal, option: true, others: true, 10.05))
    for t in stride(from: 10.1, to: 11, by: 0.05) {
        #expect(!keys(&reveal, option: true, others: true, t))
    }
    // ⌘ let go with ⌥ still down: the hold starts over.
    #expect(!keys(&reveal, option: true, 11))
    #expect(keys(&reveal, option: true, 11.2))
}
