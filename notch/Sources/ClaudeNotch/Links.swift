import AppKit
import CoreServices

/// claude:// links, sign-in callbacks among them, go to the Claude copy used last. Left to
/// itself macOS hands every one to the copy that started first, so signing in to B would
/// sign A in instead. The app owns the scheme (Info.plist) and passes each link on.
@MainActor
enum Links {
    static let scheme = "claude"

    /// Makes this app the claude:// handler unless it already is. A Claude update can claim
    /// the scheme again, so this runs at launch and whenever a copy starts.
    static func claim() {
        let me = Bundle.main
        guard me.bundleURL.pathExtension == "app", let id = me.bundleIdentifier,
              let probe = URL(string: "\(scheme)://")
        else { return }
        let handler = NSWorkspace.shared.urlForApplication(toOpen: probe).flatMap { Bundle(url: $0)?.bundleIdentifier }
        guard handler != id else { return }
        NSWorkspace.shared.setDefaultApplication(at: me.bundleURL, toOpenURLsWithScheme: scheme) { error in
            if let error {
                complain("couldn't take claude:// links: \(error.localizedDescription)")
            } else {
                log.notice("took claude:// links from \(handler ?? "nothing", privacy: .public)")
            }
        }
    }

    /// The copy a link goes to: the one used last if it's still running, else the first
    /// running one, else none.
    nonisolated static func target(lastUsed: String?, running: [String]) -> String? {
        if let lastUsed, running.contains(lastUsed) { return lastUsed }
        return running.sorted().first
    }

    static func open(_ url: URL, copies: ClaudeCopies) {
        guard let letter = target(lastUsed: copies.lastUsed, running: copies.runningLetters),
              let app = copies.running(letter)
        else {
            // No copy running: Claude itself starts (as A) with the link, as before.
            guard let claude = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ClaudeCopies.bundleID) else {
                complain("no Claude to open \(url.scheme ?? "")://… with")
                NSSound.beep()
                return
            }
            NSWorkspace.shared.open([url], withApplicationAt: claude, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        let pid = app.processIdentifier
        let link = url.absoluteString
        // The first send can wait on macOS asking whether this app may control Claude.
        DispatchQueue.global(qos: .userInitiated).async {
            let status = send(link, to: pid)
            guard status != noErr else {
                log.notice("passed a claude:// link to Claude \(letter, privacy: .public)")
                return
            }
            DispatchQueue.main.async {
                complain("couldn't pass a link to Claude \(letter) (error \(status))")
                NSSound.beep()
            }
        }
        app.activate(options: .activateAllWindows)
    }

    /// The "open location" Apple event, sent to one process rather than to the app's bundle
    /// ID (which macOS would deliver to the first copy).
    nonisolated static func send(_ link: String, to pid: pid_t) -> OSStatus {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kInternetEventClass), eventID: AEEventID(kAEGetURL),
            targetDescriptor: NSAppleEventDescriptor(processIdentifier: pid),
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
        )
        event.setParam(NSAppleEventDescriptor(string: link), forKeyword: AEKeyword(keyDirectObject))
        do {
            try event.sendEvent(options: [.noReply], timeout: 10)
            return noErr
        } catch {
            return OSStatus(truncatingIfNeeded: (error as NSError).code)
        }
    }
}
