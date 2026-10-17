import AppKit
import os

/// Switches to a Claude copy: the launcher app's own script brings a running copy forward
/// (reopening a window if it has none) or starts it. macOS sometimes ignores activating one
/// of several copies of the same app, so a running copy is asked again until it's in front.
@MainActor
enum Launcher {
    static func script(for letter: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Applications/Claude \(letter).app/Contents/Resources/claude-profile.sh")
    }

    static func switchTo(_ letter: String, copies: ClaudeCopies?) {
        let script = script(for: letter)
        guard FileManager.default.isExecutableFile(atPath: script.path(percentEncoded: false)) else {
            complain("no launcher at \(script.path(percentEncoded: false))")
            NSSound.beep()
            return
        }
        let process = Process()
        process.executableURL = script
        process.arguments = [letter]
        do { try process.run() } catch {
            complain("launcher failed: \(error.localizedDescription)")
            NSSound.beep()
            return
        }
        guard let pid = copies?.running(letter)?.processIdentifier else { return }
        Task {
            for _ in 0..<4 {
                try? await Task.sleep(for: .milliseconds(300))
                guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated,
                      NSWorkspace.shared.frontmostApplication?.processIdentifier != pid
                else { return }
                app.activate(options: .activateAllWindows)
            }
        }
    }
}

let log = Logger(subsystem: "com.godzillaaa.claude-notch", category: "app")

/// Something went wrong: to stderr and the system log, where
/// `log show --predicate 'subsystem == "com.godzillaaa.claude-notch"' --last 1h` finds it.
func complain(_ message: String) {
    FileHandle.standardError.write(Data("ClaudeNotch: \(message)\n".utf8))
    log.error("\(message, privacy: .public)")
}
