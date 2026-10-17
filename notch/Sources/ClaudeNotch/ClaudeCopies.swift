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
        guard let arguments = Self.arguments(of: pid), let letter = Self.letter(fromArguments: arguments) else { return nil }
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

    /// "--user-data-dir=…/Claude-B" is B, "…/Claude" or no such argument is A, a folder
    /// named anything else is a copy this setup didn't start.
    nonisolated static func letter(fromArguments arguments: [String]) -> String? {
        let prefix = "--user-data-dir="
        guard let argument = arguments.last(where: { $0.hasPrefix(prefix) }) else { return "A" }
        let folder = URL(filePath: String(argument.dropFirst(prefix.count))).lastPathComponent
        return Profile.letter(forFolder: folder)
    }

    /// Another process's arguments, from the kernel; readable for the user's own processes
    /// without any permission.
    nonisolated static func arguments(of pid: pid_t) -> [String]? {
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        return parseArguments(Array(buffer.prefix(size)))
    }

    /// KERN_PROCARGS2 is argc, the executable's path, NUL padding, then argc NUL-terminated
    /// arguments (then the environment, which is skipped).
    nonisolated static func parseArguments(_ bytes: [UInt8]) -> [String]? {
        guard bytes.count >= 4 else { return nil }
        let argc = Int(bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
        var i = 4
        while i < bytes.count, bytes[i] != 0 { i += 1 }
        while i < bytes.count, bytes[i] == 0 { i += 1 }
        var arguments: [String] = []
        while arguments.count < argc, i < bytes.count {
            let start = i
            while i < bytes.count, bytes[i] != 0 { i += 1 }
            arguments.append(String(decoding: bytes[start..<i], as: UTF8.self))
            i += 1
        }
        return arguments.count == argc ? arguments : nil
    }
}
