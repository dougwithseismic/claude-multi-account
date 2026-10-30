import Foundation
import Testing
@testable import UsageCore

@Suite struct ChromeAccessTests {
    @Test func onUnlessTheFileIsThere() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "chrome-\(UUID())/claude-multi-account")
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let access = ChromeAccess(folder: folder)
        #expect(access.offFile == folder.appending(path: "chrome-off"))
        #expect(access.isOn)

        // Off makes the folder too, and saying it twice is fine.
        try access.set(false)
        #expect(!access.isOn)
        #expect(FileManager.default.fileExists(atPath: access.offFile.path(percentEncoded: false)))
        try access.set(false)
        #expect(!access.isOn)

        try access.set(true)
        #expect(access.isOn)
        try access.set(true)
        #expect(access.isOn)
    }

    @Test func aShellCanFlipIt() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "chrome-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let access = ChromeAccess(folder: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // `touch`, then `rm`.
        #expect(FileManager.default.createFile(atPath: access.offFile.path(percentEncoded: false), contents: nil))
        #expect(!ChromeAccess(folder: folder).isOn)
        try FileManager.default.removeItem(at: access.offFile)
        #expect(ChromeAccess(folder: folder).isOn)
    }

    @Test func livesBesideProfilesJSON() {
        #expect(ChromeAccess().offFile == ProfileStyle.file.deletingLastPathComponent().appending(path: "chrome-off"))
        #expect(ChromeAccess.usedNotification.rawValue == "com.godzillaaa.claude-chrome-relay.used")
    }
}
