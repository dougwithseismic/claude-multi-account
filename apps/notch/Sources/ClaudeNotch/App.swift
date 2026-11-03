import AppKit
import SwiftUI
import UsageCore

// Claude Notch: every Claude account's 5-hour and weekly limits at the MacBook notch, plus
// what Hammerspoon used to do for the copies: ⌥⌘ hotkeys, the coloured window outline and
// passing claude:// links to the copy used last.
//
// `--pin` keeps the panel open; `--snapshot <file.png>` renders it and quits; `--demo` shows
// made-up accounts in every state; `--welcome` opens on the welcome page (and adds it to a
// snapshot); `--copies` opens the Copies window; `--no-notch` draws the pill used on screens
// without one; `--remove-login-item` takes the app out of login items and quits, for
// `build-app.sh --uninstall`; `--login-item` prints whether it opens at login and quits, for
// `install.sh --doctor`.

struct Options {
    var pinned = false
    var demo = false
    var noNotch = false
    var welcome = false
    var copies = false
    var snapshot: String?

    init(_ arguments: [String]) {
        pinned = arguments.contains("--pin")
        demo = arguments.contains("--demo")
        noNotch = arguments.contains("--no-notch")
        welcome = arguments.contains("--welcome")
        copies = arguments.contains("--copies")
        snapshot = Snapshot.path(in: arguments)
    }
}

@main
@MainActor
enum ClaudeNotchApp {
    static func main() {
        if CommandLine.arguments.contains("--remove-login-item") {
            LoginItem.remove()
            return
        }
        if CommandLine.arguments.contains("--login-item") {
            print(LoginItem.status)
            return
        }
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
    let model: AccountsModel
    let preferences: Preferences
    let copies = ClaudeCopies()
    let hotkeys = Hotkeys()
    let outline = Outline()
    let profiles = ProfilesFile.shared
    private(set) var controller: NotchController!
    private var copiesWindow: CopiesWindow?
    private var observers: [NSObjectProtocol] = []
    private var automationShown = Date.distantPast

    init(options: Options) {
        self.options = options
        // The demo's accounts are made up: it reads nothing, and its settings are its own.
        model = AccountsModel(reader: options.demo ? nil : AccountReader())
        preferences = options.demo
            ? Preferences(defaults: UserDefaults(suiteName: Demo.defaultsSuite)!, chrome: Demo.chromeAccess)
            : Preferences()
        super.init()
        controller = NotchController(
            model: model, preferences: preferences, pinned: options.pinned, forcePill: options.noNotch,
            actions: PanelActions(
                open: { [weak self] letter in self?.switchTo(letter) },
                refresh: { [weak self] in self?.model.refresh() },
                editProfiles: { Self.editProfiles() },
                manageCopies: { [weak self] in self?.manageCopies() },
                quit: { NSApp.terminate(nil) }
            )
        )
        controller.state.isDemo = options.demo
        model.onAlert = { [weak self] letter, alert in
            self?.controller.peek(Peek(letter: letter, kind: .alert(alert)))
        }
        // Shared for `claude-usage --cached` and the status line; the demo's numbers are made up.
        if !options.demo { model.snapshotFile = SharedSnapshot.file }
        preferences.onHotkeysChange = { [weak self] in self?.registerHotkeys() }
        profiles.onChange = { [weak self] added in self?.profilesChanged(addedByHand: added) }
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
            Snapshot.write(
                model, preferences: preferences, to: path, hasNotch: !options.noNotch, showDetails: options.demo,
                welcome: options.welcome
            )
            return
        }
        controller.start()
        // The first run opens on the welcome page by itself; the demo only with --welcome.
        if options.welcome || (!options.demo && !preferences.welcomeSeen) {
            controller.welcome()
        } else if options.demo {
            Demo.peeks(controller)
        }
        if options.copies { manageCopies() }

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

        registerHotkeys()
        guard !options.demo else { return }
        profiles.start()
        startCopies()
        model.chrome.start()
        Links.claim()
        LoginItem.enableOnFirstLaunch()
    }

    /// claude:// links, delivered here because the app owns the scheme. Can arrive before
    /// launch finishes, when a link started the app.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == Links.scheme {
            Links.open(url, copies: copies) { [weak self] letter in self?.linkBlocked(letter) }
        }
    }

    /// macOS refused to let a link through, most likely a sign-in: say so, and open the
    /// setting that allows it (Privacy & Security → Automation), at most once a minute.
    private func linkBlocked(_ letter: String) {
        controller.peek(Peek(letter: letter, kind: .linkBlocked))
        let now = Date()
        guard now.timeIntervalSince(automationShown) > 60,
              let settings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        else { return }
        automationShown = now
        NSWorkspace.shared.open(settings)
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
        log.notice("running copies \(self.copies.runningLetters, privacy: .public)")
    }

    private func registerHotkeys() {
        let plan = HotkeyPlan.bindings(AccountStyle.styles, mostRoom: preferences.mostRoomHotkey)
        let bindings = plan.map { key, target -> (key: String, action: () -> Void) in
            switch target {
            case .copy(let letter):
                return (key: key, action: { [weak self] in
                    log.notice("⌥⌘\(key, privacy: .public) switches to \(letter, privacy: .public)")
                    self?.switchTo(letter)
                    self?.controller.peek(Peek(letter: letter, kind: .switched))
                })
            case .mostRoom:
                return (key: key, action: { [weak self] in self?.switchToMostRoom() })
            }
        }
        let taken = hotkeys.register(bindings)
        if !taken.isEmpty { complain("couldn't register ⌥⌘\(taken.joined(separator: ", ⌥⌘")); another app may have them") }
        let keys = bindings.map(\.key).filter { !taken.contains($0) }.map { "⌥⌘\($0)" }.joined(separator: " ")
        log.notice("hotkeys \(keys, privacy: .public)")
    }

    /// ⌥⌘0: to the copy with the most room, from the numbers already read. With none, a
    /// peek says so and which is back first, and nothing switches.
    private func switchToMostRoom() {
        switch model.mostRoom() {
        case .copy(let letter):
            log.notice("⌥⌘0 switches to \(letter, privacy: .public), the most room")
            switchTo(letter)
            controller.peek(Peek(letter: letter, kind: .switched))
        case .noRoom(let back):
            log.notice("⌥⌘0: no copy has room")
            controller.peek(Peek(letter: back?.letter ?? "", kind: .noRoom(back)))
        }
    }

    /// The demo's copies are made up: a switch only moves which one is current.
    private func switchTo(_ letter: String) {
        if options.demo {
            model.lastUsed = letter
        } else {
            Launcher.switchTo(letter, copies: copies)
        }
    }

    /// Opens profiles.json, writing out the profiles in use first if there's no file yet.
    private static func editProfiles() {
        let file = ProfileStyle.file
        if !FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            do {
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try ProfileStyle.template(AccountStyle.styles).write(to: file, atomically: true, encoding: .utf8)
            } catch {
                complain("couldn't write \(file.path(percentEncoded: false)): \(error.localizedDescription)")
                return
            }
        }
        if !NSWorkspace.shared.open(file) { NSWorkspace.shared.activateFileViewerSelecting([file]) }
    }

    /// profiles.json changed, in the Copies window or saved by hand: names, colours and keys
    /// apply at once, and a letter added by hand gets its copy made.
    private func profilesChanged(addedByHand added: [String]) {
        AccountStyle.styles = profiles.styles
        registerHotkeys()
        model.discover()
        controller.reload()
        let unmade = added.filter { !Launcher.exists($0) }
        guard !unmade.isEmpty else { return }
        Task {
            for letter in unmade {
                do {
                    try await CopyScript.make(letter)
                    log.notice("made Claude \(letter, privacy: .public), added to profiles.json by hand")
                } catch {
                    complain("couldn't make Claude \(letter): \(error.localizedDescription)")
                }
            }
            model.discover()
        }
    }

    /// The Copies window. The demo's copies are made up, so it has none.
    private func manageCopies() {
        guard !options.demo else { return NSSound.beep() }
        let window = copiesWindow ?? CopiesWindow(
            editor: CopiesEditor(file: profiles, model: model) { [weak self] letter in self?.switchTo(letter) }
        )
        copiesWindow = window
        window.show()
    }
}
