import Foundation
import os

/// The relay's side of the system log, beside the app's:
/// `log show --predicate 'subsystem == "com.godzillaaa.claude-notch"' --last 1h --info`.
/// Only tool names and what went wrong, never a call's arguments or a page's content.
public enum Diagnostics {
    static let log = Logger(subsystem: "com.godzillaaa.claude-notch", category: "chrome-relay")

    public static func note(_ message: String) {
        log.info("\(message, privacy: .public)")
    }
}

/// Whether Chrome's native host can be reached, for `claude-chrome-relay --check` and
/// `install.sh --doctor`. Only looks for live sockets; never connects or sends anything.
public enum HostCheck {
    public struct Result: Sendable {
        public let ready: Bool
        public let message: String
    }

    static let notRunning = "Chrome's helper isn't running. Open Chrome with the Claude extension installed (it starts the helper), or restart Chrome if it's open."

    public static func run(socketPath: String? = nil) -> Result {
        if let socketPath {
            var info = stat()
            let ok = lstat(socketPath, &info) == 0 && info.st_mode & S_IFMT == S_IFSOCK
            return ok ? Result(ready: true, message: "Chrome's helper: \(socketPath)")
                : Result(ready: false, message: "\(socketPath) isn't a socket.")
        }
        do {
            let live = try HostSocket.live()
            switch live.count {
            case 0: return Result(ready: false, message: notRunning)
            case 1: return Result(ready: true, message: "Chrome's helper is running.")
            default: return Result(ready: true, message: "Chrome's helper is running in \(live.count) Chrome profiles; the relay uses the one that started last.")
            }
        } catch .unsafe(let reason) {
            return Result(ready: false, message: "Chrome's helper can't be used safely: \(reason).")
        } catch {
            return Result(ready: false, message: notRunning)
        }
    }
}
