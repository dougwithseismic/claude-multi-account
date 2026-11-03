import Foundation

/// One copy of the Claude desktop app and its data folder: "Claude" is A,
/// "Claude-<letter>" beside it is that letter (see the README).
public struct Profile: Sendable, Equatable {
    public let letter: String
    public let dataDirectory: URL

    public var configFile: URL { dataDirectory.appending(path: "config.json") }

    public init(letter: String, dataDirectory: URL) {
        self.letter = letter
        self.dataDirectory = dataDirectory
    }

    public static var applicationSupport: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
    }

    /// The copies profiles.json lists whose data folder is under `root`, opened yet or not,
    /// sorted by letter. A folder it doesn't list is a copy that was removed.
    public static func discover(in root: URL = applicationSupport, letters: [String]) -> [Profile] {
        Set(letters).sorted().compactMap { letter -> Profile? in
            let url = root.appending(path: folder(for: letter), directoryHint: .isDirectory)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory),
                  isDirectory.boolValue
            else { return nil }
            return Profile(letter: letter, dataDirectory: url)
        }
    }

    /// "Claude" for A, "Claude-B" for B.
    public static func folder(for letter: String) -> String { letter == "A" ? "Claude" : "Claude-\(letter)" }

    public static func letter(forFolder name: String) -> String? {
        if name == "Claude" { return "A" }
        guard name.hasPrefix("Claude-") else { return nil }
        let suffix = name.dropFirst("Claude-".count)
        guard suffix.count == 1, let c = suffix.first, c.isASCII, c.isUppercase, c != "A" else { return nil }
        return String(c)
    }
}

/// The two values we need from a profile's config.json.
public struct ProfileConfig: Sendable {
    public let encryptedTokenCache: String?
    public let accountUUID: String?

    public init(encryptedTokenCache: String?, accountUUID: String?) {
        self.encryptedTokenCache = encryptedTokenCache
        self.accountUUID = accountUUID
    }

    /// A copy that hasn't been opened yet has no config.json: it isn't signed in.
    public static func read(_ profile: Profile) throws -> ProfileConfig {
        guard FileManager.default.fileExists(atPath: profile.configFile.path(percentEncoded: false)) else {
            return ProfileConfig(encryptedTokenCache: nil, accountUUID: nil)
        }
        let data = try Data(contentsOf: profile.configFile)
        return try parse(data)
    }

    static func parse(_ data: Data) throws -> ProfileConfig {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.unreadableConfig
        }
        // Signing in moves the live token to V2 and empties V1, so only V2 is read.
        // An empty value means signed out, not an unreadable login.
        let cache = root["oauth:tokenCacheV2"] as? String
        return ProfileConfig(
            encryptedTokenCache: cache?.isEmpty == false ? cache : nil,
            accountUUID: root["lastKnownAccountUuid"] as? String
        )
    }
}
