import Foundation

/// What the app last read, shared with `claude-usage --cached`, the status line and any
/// other tool: `~/Library/Caches/claude-multi-account/usage.json`. Only what it takes to
/// draw a ring, for the organization each copy is working in: never a token, an email, an
/// organization's name or a UUID.
///
///     {
///       "version": 1,
///       "updatedAt": "2026-10-19T20:15:00Z",
///       "copies": [
///         { "letter": "A", "label": "Claude A", "color": "#2F7BF5", "plan": "Max 20x",
///           "inFront": true, "state": "ok", "readAt": "2026-10-19T20:15:00Z",
///           "windows": [{ "label": "5-hour", "percent": 37, "resetsAt": "2026-10-19T22:25:00Z" }] }
///       ]
///     }
public struct SharedSnapshot: Codable, Sendable, Equatable {
    public static let currentVersion = 1
    /// Older than this, the numbers say too little about now: the app has stopped reading.
    public static let freshFor: TimeInterval = 15 * 60

    public let version: Int
    /// When the app last read usage. Writes in between (a different copy in front) keep it.
    public let updatedAt: Date
    /// In profile order.
    public let copies: [Copy]

    public struct Copy: Codable, Sendable, Equatable {
        public let letter: String
        /// From profiles.json; "Claude B" instead when that label is an email.
        public let label: String
        /// "#2F7BF5".
        public let color: String
        /// "Max 20x", "Team"; never the organization's name.
        public let plan: String?
        /// The copy in front, or the one used last.
        public let inFront: Bool
        public let state: State
        /// The last good read, nil if there hasn't been one.
        public let readAt: Date?
        /// The last good numbers, kept through later failures. Empty when there are none.
        public let windows: [Window]

        public init(
            letter: String, label: String, color: String, plan: String?, inFront: Bool, state: State, readAt: Date?,
            windows: [Window]
        ) {
            self.letter = letter
            self.label = Self.safeLabel(label, letter: letter)
            self.color = color
            self.plan = plan
            self.inFront = inFront
            self.state = state
            self.readAt = readAt
            self.windows = windows
        }

        /// A label that's an email gives way to the profile's plain name.
        static func safeLabel(_ label: String, letter: String) -> String {
            label.contains("@") ? "Claude \(letter)" : label
        }

        public var report: UsageReport {
            UsageReport(windows: windows.map { UsageWindow(label: $0.label, percentUsed: $0.percent, resetsAt: $0.resetsAt) }, extraUsage: nil)
        }
    }

    public struct Window: Codable, Sendable, Equatable {
        public let label: String
        /// 0–100.
        public let percent: Double
        public let resetsAt: Date?

        public init(label: String, percent: Double, resetsAt: Date?) {
            self.label = label
            self.percent = percent
            self.resetsAt = resetsAt
        }

        public init(_ window: UsageWindow) {
            self.init(label: window.label, percent: window.percentUsed, resetsAt: window.resetsAt)
        }
    }

    /// How the organization a copy works in read last time.
    public enum State: String, Codable, Sendable {
        case ok
        /// The login expired or was revoked: the numbers are old until that copy renews it.
        case stale
        /// Anthropic answered 429; retrying later.
        case rateLimited
        case signedOut
        /// The Keychain refused Claude's key.
        case keychain
        /// Anything else: an answer this doesn't understand, the network, an unreadable login.
        case unavailable
        /// Read fine; the plan reports no limits.
        case noLimits

        /// From the last read's error, and the last good numbers.
        public init(error: UsageError?, report: UsageReport?) {
            switch error {
            case nil: self = report.map { $0.windows.isEmpty ? .noLimits : .ok } ?? .unavailable
            case .tokenExpired, .unauthorized, .noLogin: self = .stale
            case .rateLimited: self = .rateLimited
            case .notSignedIn: self = .signedOut
            case .keychain, .keychainItemMissing: self = .keychain
            default: self = .unavailable
            }
        }
    }

    public init(updatedAt: Date, copies: [Copy]) {
        version = Self.currentVersion
        self.updatedAt = updatedAt
        self.copies = copies
    }

    public func age(now: Date = Date()) -> TimeInterval { now.timeIntervalSince(updatedAt) }
    public func isFresh(now: Date = Date()) -> Bool { age(now: now) <= Self.freshFor }

    /// The copies, as `BestCopy` takes them.
    public var candidates: [BestCopy.Candidate] {
        copies.map { BestCopy.Candidate(letter: $0.letter, report: $0.report, readAt: $0.readAt) }
    }

    // MARK: The file

    /// `~/Library/Caches/claude-multi-account/usage.json`, or `$CLAUDE_NOTCH_SNAPSHOT` when
    /// that's set (for tests, and for looking at a made-up file).
    public static var file: URL {
        if let path = ProcessInfo.processInfo.environment[environmentKey], !path.isEmpty { return URL(filePath: path) }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Caches/claude-multi-account/usage.json")
    }

    public static let environmentKey = "CLAUDE_NOTCH_SNAPSHOT"

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Nil for anything but a version 1 snapshot.
    public static func decode(_ data: Data) -> SharedSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(SharedSnapshot.self, from: data), snapshot.version == currentVersion else {
            return nil
        }
        return snapshot
    }

    public static func read(from url: URL = file) -> SharedSnapshot? {
        (try? Data(contentsOf: url)).flatMap(decode)
    }

    /// Writes it in one go, readable by this user only: the folder is made 0700 if it's
    /// missing, and the file is written 0600 beside it and moved into place, so a reader
    /// never sees half a file.
    public func write(to url: URL = file) throws {
        let folder = url.deletingLastPathComponent()
        let manager = FileManager.default
        if !manager.fileExists(atPath: folder.path(percentEncoded: false)) {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        let data = try encoded()
        let temporary = folder.appending(path: ".\(url.lastPathComponent).\(UUID().uuidString)").path(percentEncoded: false)
        func failure() -> POSIXError { POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        // 0600 from the moment it exists, so nobody else can read it even briefly.
        let fd = open(temporary, O_WRONLY | O_CREAT | O_EXCL, 0o600)
        guard fd >= 0 else { throw failure() }
        let written = data.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
        close(fd)
        guard written == data.count, rename(temporary, url.path(percentEncoded: false)) == 0 else {
            let error = failure()
            unlink(temporary)
            throw error
        }
    }
}
