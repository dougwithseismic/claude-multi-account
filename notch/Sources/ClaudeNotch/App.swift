import AppKit
import SwiftUI

// Claude Notch: every Claude account's 5-hour and weekly limits at the MacBook notch, plus
// what Hammerspoon used to do for the copies: ⌥⌘ hotkeys, the coloured window outline and
// passing claude:// links to the copy used last.
//
// `--pin` keeps the panel open; `--snapshot <file.png>` renders it and quits; `--demo` shows
// made-up accounts in every state; `--no-notch` draws the pill used on screens without one.

struct Options {
    var pinned = false
    var demo = false
    var noNotch = false
    var snapshot: String?

    init(_ arguments: [String]) {
        pinned = arguments.contains("--pin")
        demo = arguments.contains("--demo")
        noNotch = arguments.contains("--no-notch")
        snapshot = Snapshot.path(in: arguments)
    }
}

@main
@MainActor
enum ClaudeNotchApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate(options: Options(CommandLine.arguments))
        app.delegate = delegate
        // No Dock icon or menu bar menu; the bundle's Info.plist also sets LSUIElement.
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let options: Options
    let model = AccountsModel()
    let copies = ClaudeCopies()
    let hotkeys = Hotkeys()
    let outline = Outline()
    private(set) var controller: NotchController!
    private var observers: [NSObjectProtocol] = []

    init(options: Options) {
        self.options = options
        super.init()
        controller = NotchController(
            model: model, pinned: options.pinned, forcePill: options.noNotch,
            open: { [weak self] letter in self?.switchTo(letter) }
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !options.demo, options.snapshot == nil, isAlreadyRunning {
            // Most likely started by a claude:// link while another copy runs: pass the link
            // on (above) and leave.
            complain("already running")
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                NSApp.terminate(nil)
            }
            return
        }
        if options.demo {
            Demo.fill(model)
            model.lastUsed = "B"
        } else {
            model.start()
        }
        if let path = options.snapshot {
            Snapshot.write(model, to: path, hasNotch: !options.noNotch)
            return
        }
        controller.start()

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.controller.screensChanged() } })

        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) {
            [weak self] _ in MainActor.assumeIsolated { self?.model.paused = true }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) {
            [weak self] _ in
            MainActor.assumeIsolated {
                self?.controller.screensChanged()
                self?.controller.bringToFront()
                self?.model.wake()
            }
        })

        guard !options.demo else { return }
        startCopies()
        Links.claim()
        LoginItem.enableOnFirstLaunch()
    }

    /// claude:// links, delivered here because the app owns the scheme. Can arrive before
    /// launch finishes, when a link started the app.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == Links.scheme {
            Links.open(url, copies: copies)
        }
    }

    private var isAlreadyRunning: Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).contains { $0 != .current }
    }

    private func startCopies() {
        copies.onFrontChange = { [weak self] app, letter in
            guard let self else { return }
            outline.follow(app?.processIdentifier, color: letter.map { AccountStyle.of($0).color })
            model.lastUsed = copies.lastUsed
        }
        copies.onLaunch = {
            // Give a freshly updated Claude time to register itself, then take the links back.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                Links.claim()
            }
        }
        copies.start()

        let bindings = AccountStyle.styles.compactMap { style -> (key: String, action: () -> Void)? in
            guard let key = style.hotkey else { return nil }
            return (key: key, action: { [weak self] in self?.switchTo(style.letter) })
        }
        let taken = hotkeys.register(bindings)
        if !taken.isEmpty { complain("couldn't register ⌥⌘\(taken.joined(separator: ", ⌥⌘")); another app may have them") }
        let keys = bindings.map(\.key).filter { !taken.contains($0) }.map { "⌥⌘\($0)" }.joined(separator: " ")
        log.notice("hotkeys \(keys, privacy: .public); running copies \(self.copies.runningLetters, privacy: .public)")
    }

    private func switchTo(_ letter: String) {
        Launcher.switchTo(letter, copies: options.demo ? nil : copies)
    }
}
