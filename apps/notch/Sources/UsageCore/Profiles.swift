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

    /// Every profile folder under `root`, sorted by letter.
    public static func discover(in root: URL = applicationSupport) -> [Profile] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path(percentEncoded: false))) ?? []
        return names.compactMap { name -> Profile? in
            guard let letter = letter(forFolder: name) else { return nil }
            let url = root.appending(path: name, directoryHint: .isDirectory)
            guard FileManager.default.fileExists(atPath: url.appending(path: "config.json").path(percentEncoded: false)) else {
                return nil
            }
            return Profile(letter: letter, dataDirectory: url)
        }
        .sorted { $0.letter < $1.letter }
    }

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

    public static func read(_ profile: Profile) throws -> ProfileConfig {
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
