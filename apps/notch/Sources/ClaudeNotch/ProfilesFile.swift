import Foundation
import Observation
import UsageCore

/// profiles.json, the list of copies with their names, colours and keys. Watched, so a save
/// in an editor applies at once, and written by the Copies window.
@MainActor @Observable
final class ProfilesFile {
    static let shared = ProfilesFile()

    /// The file's profiles, or the defaults without one.
    private(set) var styles: [ProfileStyle]
    /// Why the file doesn't read, while the profiles in use stay; nil when it does.
    private(set) var problem: String?

    /// Called after the profiles change, with the letters an edit outside the app added: a
    /// line added by hand makes its copy, as Add does in the Copies window.
    @ObservationIgnored var onChange: ((_ addedByHand: [String]) -> Void)?
    @ObservationIgnored let url: URL
    @ObservationIgnored private var stamp: Date?
    @ObservationIgnored private var timer: Timer?

    init(url: URL = ProfileStyle.file) {
        self.url = url
        styles = ProfileStyle.load(from: url)
        stamp = Self.modified(url)
    }

    func start() {
        let timer = Timer(timeInterval: 1.5, repeats: true) { _ in MainActor.assumeIsolated { self.check() } }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Reads the file again if it was saved since the last look.
    func check() {
        let now = Self.modified(url)
        guard now != stamp else { return }
        stamp = now
        reload(byHand: true)
    }

    /// Reads the file. One that doesn't read leaves the profiles in use, and says why.
    func reload(byHand: Bool = false) {
        guard let read = ProfileStyle.reload(from: url) else {
            problem = "profiles.json isn't a JSON list of profiles, so the ones in use stay. Fix it and save."
            complain("\(url.path(percentEncoded: false)) isn't a JSON list of profiles; kept the ones in use")
            return
        }
        problem = nil
        guard read != styles else { return }
        let added = byHand ? read.map(\.letter).filter { letter in !styles.contains { $0.letter == letter } } : []
        styles = read
        onChange?(added)
    }

    /// Makes `new` the profiles in use and writes them, one to a line.
    func write(_ new: [ProfileStyle]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ProfileStyle.template(new).write(to: url, atomically: true, encoding: .utf8)
        stamp = Self.modified(url)
        problem = nil
        guard new != styles else { return }
        styles = new
        onChange?([])
    }

    /// Changes one profile and writes the file.
    func update(_ letter: String, _ change: (inout ProfileStyle) -> Void) throws {
        var new = styles
        guard let i = new.firstIndex(where: { $0.letter == letter }) else { return }
        change(&new[i])
        try write(new)
    }

    private static func modified(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)))?[.modificationDate] as? Date
    }
}

/// Runs claude-copy.sh, which makes and removes copies for install.sh too: from the app's
/// Resources, or from the repository for a build run where it was built.
enum CopyScript {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static var url: URL? {
        if let bundled = Bundle.main.url(forResource: "claude-copy", withExtension: "sh") { return bundled }
        // Sources/ClaudeNotch/ in apps/notch/: the repository is five folders up.
        var repo = URL(filePath: #filePath)
        for _ in 0..<5 { repo = repo.deletingLastPathComponent() }
        let script = repo.appending(path: "files/claude-copy.sh")
        return FileManager.default.fileExists(atPath: script.path(percentEncoded: false)) ? script : nil
    }

    /// `letter`'s data folder and launcher.
    static func make(_ letter: String) async throws { try await run(["make", letter]) }

    /// `letter`'s launcher, and with `data` its data folder, which signs it out.
    static func remove(_ letter: String, data: Bool) async throws {
        try await run(["remove", letter] + (data ? ["--data"] : []))
    }

    private static func run(_ arguments: [String]) async throws {
        guard let path = url?.path(percentEncoded: false) else {
            throw Failure(message: "claude-copy.sh is missing from Claude Notch. Run ./install.sh again.")
        }
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(filePath: "/bin/zsh")
            process.arguments = [path] + arguments
            let errors = Pipe()
            process.standardError = errors
            process.standardOutput = FileHandle.nullDevice
            try process.run()
            let said = errors.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let message = String(decoding: said, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                throw Failure(message: message.isEmpty ? "claude-copy.sh \(arguments.joined(separator: " ")) failed" : message)
            }
        }.value
    }
}
