import AppKit

/// What the layout needs to know about a screen, so it can be tested without one.
/// All rects are in AppKit screen coordinates (origin bottom-left, y up).
struct ScreenShape: Equatable {
    var frame: CGRect
    var safeAreaTop: CGFloat
    var auxiliaryTopLeft: CGRect?
    var auxiliaryTopRight: CGRect?

    init(frame: CGRect, safeAreaTop: CGFloat, auxiliaryTopLeft: CGRect?, auxiliaryTopRight: CGRect?) {
        self.frame = frame
        self.safeAreaTop = safeAreaTop
        self.auxiliaryTopLeft = auxiliaryTopLeft
        self.auxiliaryTopRight = auxiliaryTopRight
    }

    @MainActor init(_ screen: NSScreen) {
        self.init(
            frame: screen.frame, safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryTopLeft: screen.auxiliaryTopLeftArea, auxiliaryTopRight: screen.auxiliaryTopRightArea
        )
    }
}

/// Where the notch is and where our two windows go.
struct NotchLayout: Equatable {
    static let ringSize: CGFloat = 16
    static let ringSpacing: CGFloat = 6
    /// How far the rings' black backing reaches into the notch, hiding its rounded corner.
    static let overlap: CGFloat = 14
    static let ringPadding: CGFloat = 8
    /// The concave curve where the black shapes meet the menu bar's top edge.
    static let flare: CGFloat = 6
    static let pillSize = CGSize(width: 168, height: 24)

    /// The cutout, or the pill drawn in its place on a screen without one.
    let notch: CGRect
    let hasNotch: Bool
    /// The rings' window: beside the notch, or the pill itself.
    let rings: CGRect
    let screenFrame: CGRect

    /// Hovering here opens the panel: the cutout itself, not the strip below it. Reaches
    /// a point above the screen so the topmost row of pixels counts.
    var trigger: CGRect { CGRect(x: notch.minX, y: notch.minY, width: notch.width, height: notch.height + 2) }

    static func make(_ screen: ScreenShape, ringCount: Int) -> NotchLayout {
        let ringsWidth = CGFloat(ringCount) * ringSize + CGFloat(max(ringCount - 1, 0)) * ringSpacing
        if screen.safeAreaTop > 0, let left = screen.auxiliaryTopLeft, let right = screen.auxiliaryTopRight {
            // The side areas aren't symmetric, so the notch is the gap between them.
            let height = screen.safeAreaTop
            let notch = CGRect(x: left.maxX, y: screen.frame.maxY - height, width: right.minX - left.maxX, height: height)
            let rings = CGRect(
                x: notch.maxX - overlap, y: notch.minY,
                width: overlap + ringPadding + ringsWidth + ringPadding + flare, height: height
            )
            return NotchLayout(notch: notch, hasNotch: true, rings: rings, screenFrame: screen.frame)
        }
        // No notch: a pill at the top centre of the menu bar, with the rings inside it.
        let pill = CGRect(
            x: screen.frame.midX - pillSize.width / 2, y: screen.frame.maxY - pillSize.height,
            width: pillSize.width, height: pillSize.height
        )
        return NotchLayout(notch: pill, hasNotch: false, rings: pill, screenFrame: screen.frame)
    }

    /// The open panel: hanging from the top of the screen, centred on the notch, kept on screen.
    func panelFrame(contentSize: CGSize) -> CGRect {
        let width = min(max(contentSize.width, notch.width + 2 * Self.flare), screenFrame.width)
        let x = min(max(notch.midX - width / 2, screenFrame.minX), screenFrame.maxX - width)
        return CGRect(x: x, y: screenFrame.maxY - contentSize.height, width: width, height: contentSize.height)
    }

    /// Room round the open panel for its shadow and the spring's overshoot.
    static let margin: CGFloat = 36
    /// The line a peek adds under the notch.
    static let peekLine: CGFloat = 30

    /// A peek: the notch widened evenly on both sides, past the rings, with a line under it.
    var peek: CGRect {
        let wings = max(92, rings.maxX - notch.maxX + 8)
        return CGRect(
            x: notch.minX - wings, y: notch.minY - Self.peekLine,
            width: notch.width + 2 * wings, height: notch.height + Self.peekLine
        )
    }

    /// The window round a panel: the panel plus the margin at the sides and below.
    static func stageFrame(panel: CGRect) -> CGRect {
        CGRect(x: panel.minX - margin, y: panel.minY - margin, width: panel.width + 2 * margin, height: panel.height + margin)
    }

    /// A screen rect in a panel's own coordinates (origin top-left, y down).
    static func local(_ rect: CGRect, in panel: CGRect) -> CGRect {
        CGRect(x: rect.minX - panel.minX, y: panel.maxY - rect.maxY, width: rect.width, height: rect.height)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }

    /// The first screen with a notch, else the built-in display, else the main screen.
    @MainActor static var notchScreen: NSScreen? {
        screens.first { $0.safeAreaInsets.top > 0 }
            ?? screens.first { $0.displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false }
            ?? main
    }

    /// Identifies the current set of displays and their frames, to tell a real change
    /// from the many repeat notifications macOS sends.
    @MainActor static var arrangement: [String] {
        screens.map { "\($0.displayID ?? 0) \(NSStringFromRect($0.frame)) \($0.safeAreaInsets.top)" }.sorted()
    }
}
