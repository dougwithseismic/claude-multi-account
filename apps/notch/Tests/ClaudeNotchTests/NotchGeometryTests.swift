import AppKit
import Testing
@testable import ClaudeNotch

/// A 14-inch MacBook Pro at its default scale: 1512×982 points, a 38pt menu bar, and
/// side areas that aren't the same width.
let macBook = ScreenShape(
    frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
    safeAreaTop: 38,
    auxiliaryTopLeft: CGRect(x: 0, y: 944, width: 664, height: 38),
    auxiliaryTopRight: CGRect(x: 849, y: 944, width: 663, height: 38)
)

@Test func notchIsTheGapBetweenTheSideAreas() {
    let layout = NotchLayout.make(macBook, ringCount: 3)
    #expect(layout.hasNotch)
    #expect(layout.notch == CGRect(x: 664, y: 944, width: 185, height: 38))
}

@Test func ringsSitJustRightOfTheNotch() {
    let layout = NotchLayout.make(macBook, ringCount: 3)
    #expect(layout.rings.minX == layout.notch.maxX - NotchLayout.overlap)
    #expect(layout.rings.maxY == macBook.frame.maxY)
    #expect(layout.rings.height == 38)
    // Three 16pt rings with 6pt gaps, padding on both sides and the flare.
    #expect(layout.rings.width == NotchLayout.overlap + 8 + 3 * 16 + 2 * 6 + 8 + NotchLayout.flare)
}

@Test func triggerIsTheCutoutAndTheTopEdge() {
    let layout = NotchLayout.make(macBook, ringCount: 3)
    #expect(layout.trigger.contains(CGPoint(x: 700, y: 982)))
    #expect(layout.trigger.contains(CGPoint(x: 700, y: 950)))
    // The strip below the notch doesn't open the panel, nor does the menu bar beside it.
    #expect(!layout.trigger.contains(CGPoint(x: 700, y: 940)))
    #expect(!layout.trigger.contains(CGPoint(x: 860, y: 960)))
}

@Test func panelHangsFromTheTopCentredOnTheNotch() {
    let layout = NotchLayout.make(macBook, ringCount: 3)
    let frame = layout.panelFrame(contentSize: CGSize(width: 460, height: 300))
    #expect(frame.midX == layout.notch.midX)
    #expect(frame.maxY == 982)
    #expect(frame.height == 300)
}

@Test func panelIsNeverNarrowerThanTheNotchAndStaysOnScreen() {
    let layout = NotchLayout.make(macBook, ringCount: 3)
    #expect(layout.panelFrame(contentSize: CGSize(width: 50, height: 100)).width == 185 + 2 * NotchLayout.flare)
    let wide = layout.panelFrame(contentSize: CGSize(width: 2000, height: 100))
    #expect(wide.minX == 0 && wide.width == 1512)
}

@Test func noNotchGivesAPillAtTheTopCentre() {
    let external = ScreenShape(
        frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
        safeAreaTop: 0, auxiliaryTopLeft: nil, auxiliaryTopRight: nil
    )
    let layout = NotchLayout.make(external, ringCount: 3)
    #expect(!layout.hasNotch)
    #expect(layout.notch == CGRect(x: 1512 + 1280 - 84, y: 1440 - 24, width: 168, height: 24))
    #expect(layout.rings == layout.notch)
}

@Test func aPeekIsCentredOnTheNotchAndReachesPastTheRings() {
    let layout = NotchLayout.make(macBook, ringCount: 3)
    #expect(layout.peek.midX == layout.notch.midX)
    #expect(layout.peek.maxY == 982)
    #expect(layout.peek.height == 38 + NotchLayout.peekLine)
    #expect(layout.peek.maxX >= layout.rings.maxX)
    // Six copies make the rings wider: the peek widens with them.
    let six = NotchLayout.make(macBook, ringCount: 6)
    #expect(six.peek.maxX >= six.rings.maxX && six.peek.width > layout.peek.width)
}

@Test func theWindowLeavesRoomRoundThePanel() {
    let panel = CGRect(x: 100, y: 600, width: 460, height: 382)
    let frame = NotchLayout.stageFrame(panel: panel)
    #expect(frame.maxY == panel.maxY)
    #expect(frame.minX == panel.minX - NotchLayout.margin && frame.maxX == panel.maxX + NotchLayout.margin)
    #expect(frame.minY == panel.minY - NotchLayout.margin)
}

@Test func theNotchInThePanelsOwnCoordinates() {
    let layout = NotchLayout.make(macBook, ringCount: 3)
    let panel = layout.panelFrame(contentSize: CGSize(width: 460, height: 300))
    let notch = NotchLayout.local(layout.notch, in: panel)
    #expect(notch == CGRect(x: 137.5, y: 0, width: 185, height: 38))
}
