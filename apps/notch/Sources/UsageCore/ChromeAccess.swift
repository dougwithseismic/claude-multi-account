import Foundation

/// Whether `claude-chrome-relay` may use Chrome: one switch for every copy. Off is a file,
/// `~/.config/claude-multi-account/chrome-off`, rather than a setting, because the relay is
/// a separate process that runs as long as its session and has to see a change on its very
/// next call. A shell can flip it too: `touch` the file to turn access off, `rm` it to turn
/// it back on.
public struct ChromeAccess: Sendable {
    /// Turns access off while it exists.
    public let offFile: URL

    /// Posted by the relay after each call it makes to Chrome, with the copy's letter as the
    /// object, so Claude Notch can mark that copy's row.
    public static let usedNotification = Notification.Name("com.godzillaaa.claude-chrome-relay.used")

    public init(folder: URL = ProfileStyle.file.deletingLastPathComponent()) {
        offFile = folder.appending(path: "chrome-off")
    }

    public var isOn: Bool { !FileManager.default.fileExists(atPath: offFile.path(percentEncoded: false)) }

    /// Turns access on by removing the file, or off by creating it (and its folder).
    public func set(_ on: Bool) throws {
        let files = FileManager.default
        if on {
            do { try files.removeItem(at: offFile) } catch CocoaError.fileNoSuchFile {}
        } else if isOn {
            try files.createDirectory(at: offFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: offFile)
        }
    }
}
