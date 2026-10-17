import AppKit
import SwiftUI

/// A borderless, non-activating panel that sits over the menu bar on every Space and
/// never takes focus, so clicking a row leaves the frontmost app alone until the launcher runs.
final class NotchPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        appearance = NSAppearance(named: .darkAqua)
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    /// Without this AppKit pushes the panel down below the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Takes clicks in a window that never becomes key.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Places the rings beside the notch and opens the panel when the pointer rests on the notch.
@MainActor
final class NotchController {
    let model: AccountsModel
    /// Keeps the panel open, for screenshots (`--pin`).
    let pinned: Bool
    /// Draws the pill even on a screen with a notch (`--no-notch`).
    let forcePill: Bool
    private let open: (String) -> Void
    private let rings = NotchPanel()
    private let panel = NotchPanel()
    private var layout: NotchLayout?
    private var arrangement: [String] = []
    private var ringCount = 0
    private var gate = HoverGate()
    private var hoverTimer: Timer?

    init(model: AccountsModel, pinned: Bool, forcePill: Bool, open: @escaping (String) -> Void) {
        self.model = model
        self.pinned = pinned
        self.forcePill = forcePill
        self.open = open
        // The rings never take clicks: they pass through to the menu bar beneath. The open
        // panel is left alone, so only its transparent pixels pass clicks through.
        rings.ignoresMouseEvents = true
        model.onChange = { [weak self] in self?.modelChanged() }
    }

    func start() {
        rebuild()
        let timer = Timer(timeInterval: 0.05, repeats: true) { _ in MainActor.assumeIsolated { self.tick() } }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
        if pinned { show() }
    }

    /// Lays both windows out on the notch screen again; ignores repeat notifications for
    /// the same displays and frames.
    func screensChanged() {
        guard NSScreen.arrangement != arrangement else { return }
        rebuild()
    }

    /// boring.notch users report the panel vanishing after long sleeps, so bring both back.
    func bringToFront() {
        rings.orderFrontRegardless()
        if gate.isOpen || pinned { panel.orderFrontRegardless() }
    }

    private func rebuild() {
        arrangement = NSScreen.arrangement
        ringCount = model.profiles.count
        guard let screen = NSScreen.notchScreen else { return }
        var shape = ScreenShape(screen)
        if forcePill { shape.safeAreaTop = 0 }
        let layout = NotchLayout.make(shape, ringCount: ringCount)
        self.layout = layout
        rings.contentView = FirstClickHostingView(rootView: RingsView(model: model, hasNotch: layout.hasNotch))
        rings.setFrame(layout.rings, display: true)
        rings.orderFrontRegardless()
        panel.contentView = FirstClickHostingView(
            rootView: PanelView(
                model: model, topInset: layout.notch.height,
                open: { [weak self] letter in self?.switchTo(letter) },
                quit: { NSApp.terminate(nil) },
                footerExtras: AnyView(LoginItemToggle())
            )
        )
        if panel.isVisible { resizePanel() }
    }

    private func modelChanged() {
        // A profile appearing or going changes how wide the rings are (one ring per copy).
        if model.profiles.count != ringCount { rebuild() }
        if panel.isVisible { resizePanel() }
    }

    private func tick() {
        guard let layout, !pinned else { return }
        let mouse = NSEvent.mouseLocation
        let changed = gate.update(
            inTrigger: layout.trigger.contains(mouse),
            inPanel: panel.isVisible && panel.frame.contains(mouse),
            buttonDown: NSEvent.pressedMouseButtons != 0,
            now: ProcessInfo.processInfo.systemUptime
        )
        guard changed else { return }
        gate.isOpen ? show() : close()
    }

    private func show() {
        model.refreshIfStale()
        resizePanel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    private func close() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.gate.isOpen, !self.pinned else { return }
                self.panel.orderOut(nil)
            }
        })
    }

    private func resizePanel() {
        guard let layout, let view = panel.contentView else { return }
        panel.setFrame(layout.panelFrame(contentSize: view.fittingSize), display: true)
    }

    private func switchTo(_ letter: String) {
        open(letter)
        if !pinned {
            gate.close()
            close()
        }
    }
}
