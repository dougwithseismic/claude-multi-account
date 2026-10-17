import CryptoKit
import Foundation
import SQLite3

/// Which organization a copy is working in. One account can belong to several (a personal
/// Max plan and a Team, say), each with its own limits, and Claude's organization switcher
/// records the choice in a `lastActiveOrg` cookie on claude.ai, as openusage reads it.
public enum ActiveOrganization {
    static let cookieDatabases = ["Cookies", "Network/Cookies"]
    static let cookieHosts: Set<String> = [".claude.ai", "claude.ai"]

    /// The cookie, else the organization Claude last recorded usage for.
    public static func read(_ profile: Profile, key: Data) -> String? {
        cookie(in: profile, key: key) ?? lastUsageSample(in: profile)
    }

    static func cookie(in profile: Profile, key: Data) -> String? {
        for name in cookieDatabases {
            let url = profile.dataDirectory.appending(path: name)
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)),
                  let cookies = try? storedCookies(databaseAt: url)
            else { continue }
            if let organization = cookies.lazy.compactMap({ value(of: $0, key: key) }).first { return organization }
        }
        return nil
    }

    struct StoredCookie {
        let host: String
        let value: Data
        let encryptedValue: Data
    }

    /// The `lastActiveOrg` cookies, newest first. Opened read-only and immutable: Claude
    /// keeps the database locked while it runs, and nothing here may write to it.
    static func storedCookies(databaseAt url: URL) throws -> [StoredCookie] {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        guard sqlite3_open_v2(url.absoluteString + "?immutable=1", &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK
        else { throw UsageError.unreadableConfig }

        let hosts = cookieHosts.sorted().map { "'\($0)'" }.joined(separator: ", ")
        let query = "SELECT host_key, value, encrypted_value FROM cookies WHERE name = 'lastActiveOrg' AND host_key IN (\(hosts))"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        // Older Chromium databases have no last_update_utc.
        guard sqlite3_prepare_v2(db, query + " ORDER BY last_update_utc DESC", -1, &statement, nil) == SQLITE_OK
            || sqlite3_prepare_v2(db, query + " ORDER BY creation_utc DESC", -1, &statement, nil) == SQLITE_OK
        else { throw UsageError.unreadableConfig }

        var cookies: [StoredCookie] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            cookies.append(StoredCookie(
                host: sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? "",
                value: column(statement, 1),
                encryptedValue: column(statement, 2)
            ))
        }
        return cookies
    }

    private static func column(_ statement: OpaquePointer?, _ index: Int32) -> Data {
        guard let bytes = sqlite3_column_blob(statement, index) else { return Data() }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index)))
    }

    /// Chromium encrypts cookie values like config.json's, and newer versions put the
    /// SHA-256 of the host in front of the value before encrypting it.
    static func value(of cookie: StoredCookie, key: Data) -> String? {
        var plain = cookie.value
        if plain.isEmpty {
            guard let decrypted = try? SafeStorage.decrypt(cookie.encryptedValue, key: key) else { return nil }
            let hostHash = Data(SHA256.hash(data: Data(cookie.host.utf8)))
            plain = decrypted.starts(with: hostHash) ? decrypted.dropFirst(hostHash.count) : decrypted
        }
        return organization(String(decoding: plain, as: UTF8.self))
    }

    /// `plan-usage-history.json`: Claude samples the usage of the organization it's working
    /// in every few minutes, so the newest sample names it. Used when the cookie can't be read.
    static func lastUsageSample(in profile: Profile) -> String? {
        struct History: Decodable {
            struct Sample: Decodable {
                let t: Double?
                let org: String?
            }
            let samples: [Sample]?
        }
        guard let data = try? Data(contentsOf: profile.dataDirectory.appending(path: "plan-usage-history.json")),
              let history = try? JSONDecoder().decode(History.self, from: data)
        else { return nil }
        let newest = (history.samples ?? []).filter { $0.t != nil && $0.org != nil }.max { $0.t! < $1.t! }
        return newest?.org.flatMap(organization)
    }

    static func organization(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return UUID(uuidString: trimmed) == nil ? nil : trimmed.lowercased()
    }
}
