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
        // The views animate in and out; AppKit's own zoom on ordering out would follow
        // the fold with a second, smaller shrink.
        animationBehavior = .none
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

/// Places the rings beside the notch, opens the panel when the pointer rests on the notch
/// (or it's clicked), and shows peeks.
///
/// Three windows: the rings on top, which never take clicks; under them the panel, whose
/// transparent pixels pass clicks through; and the peek, which never takes clicks either.
/// The panel's black grows out from under the rings, so they stay put as it opens.
@MainActor
final class NotchController {
    static let openSpring = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let closeSpring = Animation.spring(response: 0.3, dampingFraction: 1)
    static let peekSpring = Animation.spring(response: 0.38, dampingFraction: 0.8)

    let model: AccountsModel
    let preferences: Preferences
    let state = NotchState()
    /// Keeps the panel open, for screenshots (`--pin`).
    let pinned: Bool
    /// Draws the pill even on a screen with a notch (`--no-notch`).
    let forcePill: Bool
    private var actions: PanelActions
    private let rings = NotchPanel()
    private let panel = NotchPanel()
    private let peekWindow = NotchPanel()
    private var layout: NotchLayout?
    private var arrangement: [String] = []
    private var ringCount = 0
    private var gate = HoverGate()
    private var reveal = OptionReveal()
    private var hoverTimer: Timer?
    private var clickMonitor: Any?
    /// The open panel on screen, from its content's size: the pointer keeps it open there.
    private var panelRect = CGRect.zero
    /// The pointer was already where a peek appeared: it has to leave before resting
    /// there opens the panel, so a peek can't open it under someone using a tab bar.
    private var peekArmed = true
    private var peekTask: Task<Void, Never>?
    private var shrinkTask: Task<Void, Never>?
    /// The welcome page opened by itself and Got it hasn't been pressed: the panel opens on
    /// it until it is.
    private(set) var welcoming = false

    init(model: AccountsModel, preferences: Preferences, pinned: Bool, forcePill: Bool, actions: PanelActions) {
        self.model = model
        self.preferences = preferences
        self.pinned = pinned
        self.forcePill = forcePill
        self.actions = actions
        let open = actions.open
        self.actions.open = { [weak self] letter in self?.switchTo(letter, open: open) }
        self.actions.finishWelcome = { [weak self] in self?.finishWelcome() }
        self.actions.showWelcome = { [weak self] in self?.showWelcome() }
        rings.ignoresMouseEvents = true
        rings.level = NSWindow.Level(rawValue: panel.level.rawValue + 1)
        peekWindow.ignoresMouseEvents = true
        model.onChange = { [weak self] in self?.modelChanged() }
        state.onResize = { [weak self] size in
            // Measured during a SwiftUI update: resize the window after it.
            Task { @MainActor in self?.contentResized(size) }
        }
    }

    func start() {
        rebuild()
        let timer = Timer(timeInterval: 0.05, repeats: true) { _ in MainActor.assumeIsolated { self.tick() } }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
        // Clicks elsewhere reach a global monitor without any permission; only keys need one.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            MainActor.assumeIsolated { self?.clicked() }
        }
        if pinned { show() }
    }

    /// Lays the windows out on the notch screen again; ignores repeat notifications for
    /// the same displays and frames.
    func screensChanged() {
        guard NSScreen.arrangement != arrangement else { return }
        rebuild()
    }

    /// After profiles.json changed: the rings and rows pick up new names and colours.
    func reload() { rebuild() }

    /// boring.notch users report the panel vanishing after long sleeps, so bring the windows back.
    func bringToFront() {
        rings.orderFrontRegardless()
        if state.isOpen || pinned { panel.orderFrontRegardless() }
    }

    private func rebuild() {
        arrangement = NSScreen.arrangement
        ringCount = model.profiles.count
        guard let screen = NSScreen.notchScreen else { return }
        var shape = ScreenShape(screen)
        if forcePill { shape.safeAreaTop = 0 }
        let layout = NotchLayout.make(shape, ringCount: ringCount)
        self.layout = layout

        rings.contentView = FirstClickHostingView(rootView: RingsView(model: model, hasNotch: layout.hasNotch, state: state))
        rings.setFrame(layout.ringsWindow, display: true)
        rings.orderFrontRegardless()

        state.peekSize = layout.peek.size
        state.notchInPeek = NotchLayout.local(layout.notch, in: layout.peek)
        let peek = NSHostingView(rootView: PeekStage(model: model, state: state))
        peek.sizingOptions = []
        peekWindow.contentView = peek
        peekWindow.setFrame(NotchLayout.stageFrame(panel: layout.peek), display: false)

        let hosting = FirstClickHostingView(
            rootView: PanelStage(model: model, state: state, preferences: preferences, actions: actions)
        )
        // Reports its size but leaves the window's to the controller, which only grows it
        // while open so a spring is never cut off by the window's edge.
        hosting.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hosting
        fitPanel(allowShrink: true)
    }

    private func modelChanged() {
        // A profile appearing or going changes how wide the rings are (one ring per copy).
        if model.profiles.count != ringCount { rebuild() }
    }

    // MARK: Opening and closing

    private func tick() {
        guard let layout else { return }
        if state.isOpen {
            let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let held = reveal.update(
                option: flags.contains(.option), others: !flags.isDisjoint(with: [.command, .control, .shift]),
                now: ProcessInfo.processInfo.systemUptime
            )
            if held != state.revealHeld { withAnimation(.smooth(duration: 0.2)) { state.revealHeld = held } }
        }
        guard !pinned else { return }
        let mouse = NSEvent.mouseLocation
        let inPeek = state.peekShown && layout.peek.contains(mouse)
        if !inPeek { peekArmed = true }
        gate.hoverOpens = preferences.openOn == .hover
        // Opened by itself, the welcome page stays until the pointer has been over it: then
        // it folds when the pointer leaves, as if hovered open.
        if welcoming, state.isOpen, !gate.isOpen, panelRect.contains(mouse) { _ = gate.openNow() }
        let changed = gate.update(
            inTrigger: layout.trigger.contains(mouse) || (inPeek && peekArmed),
            inPanel: state.isOpen && panelRect.contains(mouse),
            buttonDown: NSEvent.pressedMouseButtons != 0,
            now: ProcessInfo.processInfo.systemUptime,
            pointer: mouse
        )
        guard changed else { return }
        gate.isOpen ? show(haptic: true) : close()
    }

    /// A click on the notch opens the panel at once; set to open on click, a second
    /// click closes it.
    private func clicked() {
        guard let layout, !pinned, layout.trigger.contains(NSEvent.mouseLocation) else { return }
        if gate.openNow() {
            show(haptic: false)
        } else if preferences.openOn == .click {
            gate.close()
            close()
        }
    }

    private func show(haptic: Bool = false) {
        model.refreshIfStale()
        shrinkTask?.cancel()
        let fromPeek = state.peekShown
        if !panel.isVisible {
            state.openedFromPeek = fromPeek
            fitPanel(allowShrink: true)
            panel.orderFrontRegardless()
            panel.displayIfNeeded()
        }
        if fromPeek { hidePeek(animated: false) }
        if haptic, preferences.haptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        withAnimation(Self.openSpring) { state.isOpen = true }
    }

    private func close() {
        reveal = OptionReveal()
        withAnimation(Self.closeSpring) {
            state.isOpen = false
            state.openedFromPeek = false
            state.revealHeld = false
        } completion: { [weak self] in
            guard let self, !self.state.isOpen, !self.pinned else { return }
            self.panel.orderOut(nil)
            self.state.page = self.welcoming ? .welcome : .usage
        }
    }

    /// Opens the panel by itself on the welcome page, as on the first run. Until Got it,
    /// the panel opens on it again.
    func welcome() {
        welcoming = true
        state.page = .welcome
        show()
    }

    /// Got it: not again at launch, and the panel folds (or, pinned, shows the usage).
    private func finishWelcome() {
        preferences.welcomeSeen = true
        welcoming = false
        if pinned {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { state.page = .usage }
        } else {
            gate.close()
            close()
        }
    }

    /// From settings: the welcome page, for as long as the panel is open.
    private func showWelcome() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { state.page = .welcome }
    }

    private func switchTo(_ letter: String, open: (String) -> Void) {
        open(letter)
        if !pinned {
            gate.close()
            close()
        }
    }

    // MARK: Sizing

    /// Sizes the window to the content plus room for the shadow and the spring.
    private func fitPanel(allowShrink: Bool) {
        guard let layout, let view = panel.contentView else { return }
        let fitting = view.fittingSize
        let size = CGSize(width: fitting.width - 2 * NotchLayout.margin, height: fitting.height - NotchLayout.margin)
        let rect = layout.panelFrame(contentSize: size)
        panelRect = rect
        var frame = NotchLayout.stageFrame(panel: rect)
        if !allowShrink, panel.frame.height > frame.height {
            frame.origin.y = frame.maxY - panel.frame.height
            frame.size.height = panel.frame.height
        }
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        let notch = NotchLayout.local(layout.notch, in: rect), peek = NotchLayout.local(layout.peek, in: rect)
        if state.notchInPanel != notch { state.notchInPanel = notch }
        if state.peekInPanel != peek { state.peekInPanel = peek }
    }

    /// The content grew or shrank (a row, the settings page): grow the window now, shrink
    /// it once the shape has finished moving.
    private func contentResized(_ size: CGSize) {
        guard let layout, panel.isVisible else { return }
        panelRect = layout.panelFrame(contentSize: size)
        let needed = NotchLayout.stageFrame(panel: panelRect)
        if needed.height > panel.frame.height + 0.5 {
            fitPanel(allowShrink: false)
        } else if needed.height < panel.frame.height - 0.5 {
            shrinkTask?.cancel()
            shrinkTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled, let self, self.panel.isVisible else { return }
                self.fitPanel(allowShrink: true)
            }
        }
    }

    // MARK: Peeks

    /// Shows a peek for a few seconds, unless the panel is open, the setting for its kind
    /// is off, or the app in front is in full screen. ⌥⌘0 finding no room always says so:
    /// otherwise the key would seem to do nothing.
    func peek(_ peek: Peek) {
        switch peek.kind {
        case .switched: guard preferences.switchPeeks else { return }
        case .alert: guard preferences.limitAlerts else { return }
        case .noRoom: break
        }
        guard let layout, !pinned, !state.isOpen, !frontIsFullScreen else { return }
        peekTask?.cancel()
        peekArmed = !layout.peek.contains(NSEvent.mouseLocation)
        if !peekWindow.isVisible {
            peekWindow.orderFrontRegardless()
            peekWindow.displayIfNeeded()
        }
        withAnimation(.smooth(duration: 0.25)) { state.peek = peek }
        withAnimation(Self.peekSpring) { state.peekShown = true }
        peekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(peek.duration))
            guard !Task.isCancelled else { return }
            self?.hidePeek(animated: true)
        }
    }

    /// Folds the peek back into the notch; or, when the panel is opening over it, takes it
    /// away once the panel's black covers it.
    private func hidePeek(animated: Bool) {
        peekTask?.cancel()
        guard peekWindow.isVisible else { return }
        let done = { [weak self] in
            guard let self, !self.state.peekShown else { return }
            self.peekWindow.orderOut(nil)
            self.state.peek = nil
        }
        if animated {
            withAnimation(Self.closeSpring) { state.peekShown = false } completion: { done() }
        } else {
            state.peekShown = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                done()
            }
        }
    }

    /// The app in front fills a screen: no peeks over a full-screen video or slides.
    private var frontIsFullScreen: Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let primary = NSScreen.screens.first?.frame, let bounds = Outline.frontWindow(of: pid)
        else { return false }
        return Outline.isFullScreen(bounds, screens: NSScreen.screens.map { Outline.flip($0.frame, primaryHeight: primary.height) })
    }
}
