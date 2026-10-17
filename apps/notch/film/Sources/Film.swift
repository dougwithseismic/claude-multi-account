import AppKit
import ApplicationServices
import ObjectiveC
import SwiftUI
import UsageCore

// The director: plays one take of the Notch film on the real screen, with the app's own
// controller, views and outline, made-up copies and a scripted pointer.
//
// `--take film` (default) is the film, with captions, title and end card. `--take hero` is
// the silent loop: one cycle three times over, a marker at the start of each. `--fonts
// <dir>` is the site's node_modules/@fontsource. `--preview <file.png>` renders the app's
// snapshot board with the film's copies and quits, for checking without recording.

enum Take: String {
    case film, hero
}

struct FilmOptions {
    var take = Take.film
    var fonts: URL?
    var preview: String?

    init(_ arguments: [String]) {
        func value(_ flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        take = value("--take").flatMap(Take.init) ?? .film
        fonts = value("--fonts").map { URL(filePath: $0) }
        preview = value("--preview")
    }
}

@main
@MainActor
enum NotchFilm {
    static func main() {
        let app = NSApplication.shared
        let director = Director(options: FilmOptions(CommandLine.arguments))
        app.delegate = director
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(director) {}
    }
}

@MainActor
final class Director: NSObject, NSApplicationDelegate {
    static let defaultsSuite = "com.godzillaaa.claude-notch.film"

    let options: FilmOptions
    let model = AccountsModel(reader: nil)
    let preferences: Preferences
    let pillPreferences: Preferences
    let outline = Outline()
    let stage = StageState()
    let overlay = OverlayState()
    private var controller: NotchController!
    private var pill: NotchController?
    private var copies = Footage.base
    private var windows: [String: StagePanel] = [:]
    private var stageWindows: [StagePanel] = []

    private let screen: NSScreen
    private let notch: CGRect
    /// The region recorded, in screen coordinates: 1024×576 pt from the top, centred on the
    /// notch. The film is its middle 960×540.
    private let capture: CGRect
    private var t0 = ContinuousClock.now

    init(options: FilmOptions) {
        self.options = options
        for suite in [Self.defaultsSuite, Self.defaultsSuite + ".pill"] {
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        preferences = Preferences(defaults: UserDefaults(suiteName: Self.defaultsSuite)!)
        pillPreferences = Preferences(defaults: UserDefaults(suiteName: Self.defaultsSuite + ".pill")!)
        screen = NSScreen.notchScreen!
        notch = NotchLayout.make(ScreenShape(screen), ringCount: Footage.letters.count).notch
        capture = CGRect(x: notch.midX - 512, y: screen.frame.maxY - 576, width: 1024, height: 576)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let fonts = options.fonts { Typeface.register(from: fonts) }
        AccountStyle.styles = ProfileStyle.defaults
        Modifiers.install()
        InstalledCopy.install()
        model.show(profiles: Footage.profiles, accounts: Footage.accounts(Footage.empty))
        model.lastUsed = "A"

        if let path = options.preview {
            model.show(profiles: Footage.profiles, accounts: Footage.accounts(Footage.base))
            Snapshot.write(model, preferences: preferences, to: path, hasNotch: true, showDetails: true)
            return
        }
        if CommandLine.arguments.contains("--geometry") {
            // The capture region in the display's pixels, for ffmpeg's crop: x y width height.
            let scale = screen.backingScaleFactor
            let y = screen.frame.maxY - capture.maxY
            print([capture.minX - screen.frame.minX, y, capture.width, capture.height].map { String(Int($0 * scale)) }.joined(separator: " "))
            exit(0)
        }
        guard AXIsProcessTrusted() else {
            print("Not trusted for Accessibility: the pointer can't be driven. Run this from a terminal that is.")
            exit(1)
        }
        print("screen \(screen.frame) notch \(notch) capture \(capture)")

        buildStage()
        controller = makeController(pill: false)
        controller.start()
        stageWindows.last?.orderFrontRegardless()
        Pointer.jump(to: park)

        Task { @MainActor in
            t0 = ContinuousClock.now
            switch options.take {
            case .film: await film()
            case .hero: await hero()
            }
            exit(0)
        }
    }

    // MARK: The takes

    private func film() async {
        stage.spin = true
        await at(0.5); await mark()
        await at(0.9); overlay.title = true
        await at(3.6); overlay.title = false
        await at(4.2); fade(to: 0, over: 1.0)
        await at(4.8)
        update(Footage.base, alerts: false)
        caption("Each account runs in its own copy of Claude, *signed in for good.*")
        await at(8.0); caption("Every account's 5-hour and weekly limits, *beside the notch.*")

        await at(10.6)
        caption("Rest on the notch to *see them all.*")
        await Pointer.move(to: notchRest, duration: 1.1)
        await at(14.3)
        Modifiers.held = .option
        keys(["⌥"])
        caption("Names stay private until you *hold ⌥.*")
        await at(16.6)
        Modifiers.held = []
        keys(nil)

        await at(17.0)
        caption("Click a row to switch. *Nobody signs out.*")
        await Pointer.move(to: rowB, duration: 0.7)
        await at(18.6); await click()
        await at(19.3); await Pointer.move(to: park, duration: 0.9, bend: -0.1)

        await at(20.4)
        caption("Or press ⌥⌘1, 2 or 3 *from anywhere.*")
        keys(["⌥", "⌘", "3"])
        hotkey("C")
        await at(22.2)
        keys(["⌥", "⌘", "1"])
        hotkey("A")
        await at(23.9); keys(nil)

        await at(24.4)
        caption("A word under the notch at *90%*, and when one runs out.")
        update(Footage.with(copies, "B", fiveHour: 91, resetsIn: 48 * 60 + 30))
        await at(27.0)
        update(Footage.with(copies, "B", fiveHour: 100, resetsIn: 48 * 60 + 30))

        await at(32.2)
        // Every copy out at once. Each would have had its own peek as it ran out; the film
        // skips them to get to the countdown, which shows once no peek is up.
        var out = Footage.with(copies, "A", fiveHour: 100, resetsIn: Footage.hour + 52 * 60 + 30)
        out = Footage.with(out, "C", fiveHour: 100, resetsIn: 6.4)
        update(out, alerts: false)
        caption("All out? It counts down to the *first one back.*")
        await at(38.7)
        update(Footage.with(copies, "C", fiveHour: 0, resetsIn: nil))
        caption("And it tells you when one's *back.*")

        await at(41.6)
        caption("Open it on hover or click. Alerts, peeks and haptics are *up to you.*")
        await Pointer.move(to: notchRest, duration: 1.0)
        await at(44.0); await Pointer.move(to: gear, duration: 0.6)
        await at(45.0)
        caption(nil)
        await click()
        await at(48.0); await leave(left: true)

        await at(48.9); fade(to: 1, over: 0.5)
        await at(49.5); toPill()
        await at(49.9)
        fade(to: 0, over: 0.6)
        caption("No notch? It sits in a *pill* on any display.")
        await at(50.8); await Pointer.move(to: pillRest, duration: 1.0)
        await at(54.2); await leave()
        await at(55.2)
        caption(nil)
        fade(to: 1, over: 0.7)
        await at(56.0); overlay.endCard = true
        await at(60.0); await mark()
        await at(60.4)
    }

    /// One cycle, three times over, each starting on the same frame: the closed rings with
    /// A current, the pointer out of shot and no peek showing.
    private func hero() async {
        stage.spin = false
        update(Footage.base, alerts: false)
        await at(0.3); fade(to: 0, over: 0.6)
        for cycle in 0..<3 {
            let start = 1.5 + 12 * Double(cycle)
            await at(start); await mark()
            await at(start + 1.0); await Pointer.move(to: notchRest, duration: 0.9)
            await at(start + 5.0); await leave()
            await at(start + 6.6); hotkey("B")
            await at(start + 9.0); hotkey("A")
        }
        await at(1.5 + 36); await mark()
        await at(38.0)
    }

    // MARK: What the app would do

    /// A row's click: in the app it starts or brings forward that copy of Claude, whose
    /// window the outline then follows.
    private func switchTo(_ letter: String) {
        model.lastUsed = letter
        guard let window = windows[letter] else { return }
        window.orderFrontRegardless()
        stage.front = letter
        outline.follow(ProcessInfo.processInfo.processIdentifier, color: AccountStyle.of(letter).color)
    }

    /// What ⌥⌘ and a profile's key run in the app: the switch, then the peek naming it.
    private func hotkey(_ letter: String) {
        switchTo(letter)
        (pill ?? controller).peek(Peek(letter: letter, kind: .switched))
    }

    /// New numbers, as a read would bring them, with the peeks `AccountsModel.apply` would raise.
    private func update(_ next: [Footage.Copy], alerts: Bool = true) {
        copies = next
        let accounts = Footage.accounts(next)
        let found = alerts ? Footage.alerts(from: model.accounts, to: accounts) : []
        model.show(profiles: Footage.profiles, accounts: accounts)
        for (letter, alert) in found { controller.peek(Peek(letter: letter, kind: .alert(alert))) }
    }

    private func makeController(pill: Bool) -> NotchController {
        NotchController(
            model: model, preferences: pill ? pillPreferences : preferences, pinned: false, forcePill: pill,
            actions: PanelActions(open: { [weak self] letter in self?.switchTo(letter) })
        )
    }

    /// The same copies on a display without a notch: the notch's windows go, the pill's come.
    private func toPill() {
        // The notch's controller keeps sampling the pointer; on click only, it never opens.
        preferences.openOn = .click
        for window in NSApp.windows where window is NotchPanel { window.orderOut(nil) }
        stage.showNotch = false
        let pill = makeController(pill: true)
        pill.start()
        self.pill = pill
        stageWindows.last?.orderFrontRegardless()
    }

    // MARK: The stage

    private func buildStage() {
        let frame = screen.frame
        // The film's crop in the backdrop's own coordinates (origin top-left).
        let film = CGRect(x: notch.midX - 480 - frame.minX, y: 0, width: 960, height: 540)

        let backdrop = StagePanel(frame: frame, level: .normal)
        backdrop.contentView = hosting(Backdrop(stage: stage, frame: film).frame(width: frame.width, height: frame.height))
        backdrop.orderFrontRegardless()
        stageWindows.append(backdrop)

        if options.take == .film {
            let left = notch.midX - 480
            let places: [(String, String, CGFloat, CGFloat)] = [
                ("C", "Pro", 494, 206), ("B", "Team", 265, 178), ("A", "Max 20x", 36, 150),
            ]
            for (letter, plan, x, top) in places {
                let size = CGSize(width: 430, height: 400)
                let window = StagePanel(
                    frame: CGRect(x: left + x, y: frame.maxY - top - size.height, width: size.width, height: size.height),
                    level: .normal
                )
                window.hasShadow = true
                window.contentView = hosting(CopyWindow(letter: letter, plan: plan, stage: stage).frame(width: size.width, height: size.height))
                window.orderFrontRegardless()
                windows[letter] = window
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                self.windows.values.forEach { $0.invalidateShadow() }
                self.switchTo("A")
            }
        }

        let strip = StagePanel(
            frame: CGRect(x: frame.minX, y: frame.maxY - notch.height, width: frame.width, height: notch.height),
            level: NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        )
        strip.ignoresMouseEvents = true
        let notchInStrip = CGRect(x: notch.minX - frame.minX, y: 0, width: notch.width, height: notch.height)
        strip.contentView = hosting(MenuStrip(stage: stage, screen: frame.size, frame: film, notch: notchInStrip))
        strip.orderFrontRegardless()
        stageWindows.append(strip)

        let top = StagePanel(frame: capture, level: NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 3))
        top.ignoresMouseEvents = true
        top.contentView = hosting(Overlay(
            state: overlay, capture: capture, frame: CGRect(x: 32, y: 0, width: 960, height: 540)
        ))
        top.orderFrontRegardless()
        stageWindows.append(top)
    }

    private func hosting<Content: View>(_ view: Content) -> NSView {
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        return hosting
    }

    // MARK: Places on screen

    private var top: CGFloat { screen.frame.maxY }
    /// Out of shot, below and right of the frame.
    private var park: CGPoint { CGPoint(x: notch.midX + 430, y: top - 760) }
    /// On the notch.
    private var notchRest: CGPoint { CGPoint(x: notch.midX + 18, y: notch.midY + 2) }
    /// Row B's header, in the open panel.
    private var rowB: CGPoint { CGPoint(x: notch.midX + 64, y: top - 186) }
    /// The gear, first in the strip left of the notch.
    private var gear: CGPoint { CGPoint(x: notch.midX - 200, y: top - 19) }
    private var pillRest: CGPoint { CGPoint(x: screen.frame.midX + 12, y: top - 12) }

    /// Out of shot without crossing the panel's rows, whose reset times would flicker to
    /// clock times under the pointer: along the top edge past the panel, then down.
    private func leave(left: Bool = false) async {
        let side: CGFloat = left ? -1 : 1
        await Pointer.move(to: CGPoint(x: notch.midX + side * 290, y: top - 22), duration: 0.45, bend: 0)
        await Pointer.move(to: CGPoint(x: notch.midX + side * 430, y: top - 760), duration: 0.75, bend: -0.1 * side)
    }

    // MARK: Timing and the overlay

    private func at(_ seconds: Double) async {
        try? await ContinuousClock().sleep(until: t0 + .seconds(seconds))
    }

    private func click() async {
        overlay.click = Date()
        await Pointer.click()
    }

    /// The sync marker, outside the film's crop: about seven frames of white.
    private func mark() async {
        overlay.marker = true
        try? await Task.sleep(for: .milliseconds(120))
        overlay.marker = false
    }

    private func fade(to curtain: Double, over seconds: Double) {
        withAnimation(.smooth(duration: seconds)) { overlay.curtain = curtain }
    }

    private func caption(_ text: String?) {
        overlay.caption = text.map { OverlayState.Caption(text: $0) }
    }

    private func keys(_ keys: [String]?) {
        overlay.keys = keys.map { OverlayState.Keys(keys: $0) }
    }
}

/// The settings page dims "Open at login" for a copy outside an Applications folder. The
/// film's copy stands in for the installed app, so it answers as if it were in /Applications.
enum InstalledCopy {
    static func install() {
        guard let original = class_getInstanceMethod(Bundle.self, #selector(getter: Bundle.bundleURL)),
              let stand = class_getInstanceMethod(Bundle.self, #selector(Bundle.filmBundleURL))
        else { return }
        method_exchangeImplementations(original, stand)
    }
}

extension Bundle {
    /// Swapped with `bundleURL`, so calling it here reaches the real one.
    @objc fileprivate func filmBundleURL() -> URL {
        self == Bundle.main ? URL(filePath: "/Applications/Claude Notch.app") : filmBundleURL()
    }
}
