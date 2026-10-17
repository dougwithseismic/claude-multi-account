import AppKit
import SwiftUI

/// A line in the copy's colour round the front window of whichever Claude copy is in front,
/// so it's clear which account you're typing into. Hidden in full screen and whenever
/// another app is in front.
///
/// The frame comes from the window server's window list, which gives every window's bounds
/// without Accessibility permission. It's sampled while a Claude copy is in front, so the
/// line follows a window being dragged or resized.
@MainActor
final class Outline {
    static let lineWidth: CGFloat = 4
    static let gap: CGFloat = 3
    static let radius: CGFloat = 14

    private let window: NSPanel
    private var timer: Timer?
    private var pid: pid_t?
    private var color: Color?

    init() {
        window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.ignoresMouseEvents = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
    }

    /// Outlines `pid`'s front window in `color`, or hides the outline for nil.
    func follow(_ pid: pid_t?, color: Color?) {
        if color != self.color, let color {
            window.contentView = NSHostingView(rootView: OutlineShape(color: color))
        }
        self.pid = pid
        self.color = color
        guard pid != nil else {
            timer?.invalidate()
            timer = nil
            window.orderOut(nil)
            return
        }
        if timer == nil {
            let timer = Timer(timeInterval: 0.05, repeats: true) { _ in MainActor.assumeIsolated { self.update() } }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        update()
    }

    private func update() {
        guard let pid, let primary = NSScreen.screens.first?.frame,
              let bounds = Self.frontWindow(of: pid),
              !Self.isFullScreen(bounds, screens: NSScreen.screens.map { Self.flip($0.frame, primaryHeight: primary.height) })
        else {
            window.orderOut(nil)
            return
        }
        let frame = Self.flip(bounds, primaryHeight: primary.height).insetBy(dx: -Self.gap, dy: -Self.gap)
        if window.frame != frame { window.setFrame(frame, display: true) }
        if !window.isVisible { window.orderFrontRegardless() }
    }

    /// The bounds of `pid`'s frontmost ordinary window in window-server coordinates
    /// (origin top-left of the main display, y down). The list runs front to back.
    static func frontWindow(of pid: pid_t) -> CGRect? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
        for info in list {
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let dictionary = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
                  bounds.width >= 100, bounds.height >= 100
            else { continue }
            return bounds
        }
        return nil
    }

    /// Between window-server coordinates and AppKit's (origin bottom-left, y up); the same
    /// flip both ways.
    nonisolated static func flip(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// A window filling a whole screen is in full screen (or as good as), and a line round
    /// it would only cover the screen's edges.
    nonisolated static func isFullScreen(_ bounds: CGRect, screens: [CGRect]) -> Bool {
        screens.contains { screen in
            abs(screen.minX - bounds.minX) < 1 && abs(screen.minY - bounds.minY) < 1
                && abs(screen.width - bounds.width) < 1 && abs(screen.height - bounds.height) < 1
        }
    }
}

struct OutlineShape: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: Outline.radius).strokeBorder(color, lineWidth: Outline.lineWidth)
    }
}
