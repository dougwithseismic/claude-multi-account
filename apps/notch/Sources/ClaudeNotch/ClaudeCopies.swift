import AppKit
import UsageCore

/// The running copies of Claude, which letter each one is, and which was in front last.
/// A copy's letter comes from the data folder it was started with (none means A), so it
/// holds across restarts and updates.
@MainActor
final class ClaudeCopies {
    nonisolated static let bundleID = "com.anthropic.claudefordesktop"
    nonisolated static let lastUsedKey = "lastUsedCopy"

    /// The copy in front, or the one that was last: where the next claude:// link goes.
    private(set) var lastUsed: String? = UserDefaults.standard.string(forKey: lastUsedKey)
    /// Called when another app comes to the front, with the Claude copy in front (or nil).
    var onFrontChange: ((NSRunningApplication?, String?) -> Void)?
    /// Called when a Claude copy starts.
    var onLaunch: (() -> Void)?

    private var letters: [pid_t: String] = [:]
    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
                MainActor.assumeIsolated {
                    if name == NSWorkspace.didTerminateApplicationNotification, let pid { self?.letters[pid] = nil }
                    self?.frontChanged()
                }
            })
        }
        observers.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) {
            [weak self] note in
            let isClaude = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier == Self.bundleID
            MainActor.assumeIsolated { if isClaude { self?.onLaunch?() } }
        })
        frontChanged()
    }

    /// The letter of a running Claude copy, or nil for any other app.
    func letter(of app: NSRunningApplication) -> String? {
        guard app.bundleIdentifier == Self.bundleID else { return nil }
        let pid = app.processIdentifier
        if let known = letters[pid] { return known }
        guard let arguments = ClaudeProcess.arguments(of: pid), let letter = ClaudeProcess.letter(fromArguments: arguments) else { return nil }
        letters[pid] = letter
        return letter
    }

    func running(_ letter: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID)
            .first { !$0.isTerminated && self.letter(of: $0) == letter }
    }

    /// Every running copy's letter.
    var runningLetters: [String] {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID)
            .filter { !$0.isTerminated }.compactMap { letter(of: $0) }.sorted()
    }

    private func frontChanged() {
        let front = NSWorkspace.shared.frontmostApplication
        let letter = front.flatMap { self.letter(of: $0) }
        if let letter, letter != lastUsed {
            lastUsed = letter
            UserDefaults.standard.set(letter, forKey: Self.lastUsedKey)
        }
        onFrontChange?(letter == nil ? nil : front, letter)
    }
}
