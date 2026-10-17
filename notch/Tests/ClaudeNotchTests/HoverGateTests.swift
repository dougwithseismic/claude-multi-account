import Testing
@testable import ClaudeNotch

/// `#expect` can't call a mutating method on a local, so samples go through this.
private func feed(_ gate: inout HoverGate, _ inTrigger: Bool, _ inPanel: Bool, _ buttonDown: Bool, _ now: Double) -> Bool {
    gate.update(inTrigger: inTrigger, inPanel: inPanel, buttonDown: buttonDown, now: now)
}

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
