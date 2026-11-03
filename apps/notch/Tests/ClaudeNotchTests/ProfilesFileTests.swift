import Foundation
import Testing
@testable import ClaudeNotch
@testable import UsageCore

@MainActor @Suite struct ProfilesFileTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "profiles-file-\(UUID())")
    var url: URL { folder.appending(path: "profiles.json") }

    @Test func withoutAFileItsTheDefaultsAndWritingMakesOne() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = ProfilesFile(url: url)
        #expect(file.styles == ProfileStyle.defaults)
        var changes: [[String]] = []
        file.onChange = { changes.append($0) }
        let d = try #require(ProfileStyle.next(after: file.styles))
        try file.write(file.styles + [d])
        #expect(ProfileStyle.load(from: url).map(\.letter) == ["A", "B", "C", "D"])
        #expect(file.styles.map(\.letter) == ["A", "B", "C", "D"])
        // The app's own write isn't an edit by hand, and the watcher doesn't read it again.
        #expect(changes == [[]])
        file.check()
        #expect(changes == [[]])
        try file.update("D") { $0.label = "Side project" }
        #expect(ProfileStyle.load(from: url).last?.label == "Side project")
    }

    @Test func aSaveByHandAppliesAndSaysWhichLettersItAdded() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try ProfileStyle.template(ProfileStyle.defaults).write(to: url, atomically: true, encoding: .utf8)
        let file = ProfilesFile(url: url)
        var added: [[String]] = []
        file.onChange = { added.append($0) }
        let e = ProfileStyle(letter: "E", label: "Claude E", color: "#B04FFF", hotkey: "5")
        try ProfileStyle.template(ProfileStyle.defaults + [e]).write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: url.path(percentEncoded: false))
        file.check()
        #expect(added == [["E"]])
        #expect(file.styles.last == e)
        #expect(file.problem == nil)
    }

    @Test func aBrokenSaveKeepsWhatsInUseAndSaysSo() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try ProfileStyle.template(ProfileStyle.defaults).write(to: url, atomically: true, encoding: .utf8)
        let file = ProfilesFile(url: url)
        var changed = false
        file.onChange = { _ in changed = true }
        try Data("[{ \"letter\": \"A\", ".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: url.path(percentEncoded: false))
        file.check()
        #expect(!changed)
        #expect(file.styles == ProfileStyle.defaults)
        #expect(file.problem != nil)
    }

    @Test func aKeyAnotherCopyHasIsntOffered() {
        let editor = CopiesEditor(file: ProfilesFile(url: url), model: AccountsModel(reader: nil)) { _ in }
        #expect(editor.keys(for: "A") == ["1", "4", "5", "6", "7", "8", "9", "0"])
        #expect(editor.next?.letter == "D")
    }
}
