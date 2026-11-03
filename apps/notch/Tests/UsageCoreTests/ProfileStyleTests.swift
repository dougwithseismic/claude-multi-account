import Foundation
import Testing
@testable import UsageCore

@Suite struct ProfileStyleTests {
    @Test func readsEachEntry() throws {
        let json = #"""
        [
          { "letter": "A", "label": "Work", "color": "#2F7BF5", "hotkey": "1" },
          { "letter": "D", "label": "Claude D", "color": "B04FD6", "hotkey": "d" }
        ]
        """#
        let styles = try #require(ProfileStyle.parse(Data(json.utf8)))
        #expect(styles == [
            ProfileStyle(letter: "A", label: "Work", color: "#2F7BF5", hotkey: "1"),
            ProfileStyle(letter: "D", label: "Claude D", color: "B04FD6", hotkey: "D"),
        ])
    }

    @Test func fillsInWhatsMissingAndSkipsWhatsWrong() throws {
        let json = #"""
        [
          { "letter": "B" },
          { "letter": "C", "color": "orange", "hotkey": "33" },
          { "letter": "ab", "label": "two letters" },
          { "letter": "e" },
          "not an object"
        ]
        """#
        let styles = try #require(ProfileStyle.parse(Data(json.utf8)))
        #expect(styles == [
            ProfileStyle(letter: "B", label: "Claude B", color: "#B3B3B3", hotkey: nil),
            ProfileStyle(letter: "C", label: "Claude C", color: "#B3B3B3", hotkey: nil),
        ])
    }

    @Test func aMissingOrBrokenFileGivesTheDefaults() throws {
        let missing = FileManager.default.temporaryDirectory.appending(path: "no-such-\(UUID()).json")
        #expect(ProfileStyle.load(from: missing) == ProfileStyle.defaults)
        let broken = FileManager.default.temporaryDirectory.appending(path: "broken-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: broken) }
        try Data("{ not json".utf8).write(to: broken)
        #expect(ProfileStyle.load(from: broken) == ProfileStyle.defaults)
        #expect(ProfileStyle.parse(Data("[]".utf8)) == nil)
    }

    @Test func aReloadOfABrokenFileSaysSo() throws {
        let missing = FileManager.default.temporaryDirectory.appending(path: "no-such-\(UUID()).json")
        #expect(ProfileStyle.reload(from: missing) == ProfileStyle.defaults)
        let file = FileManager.default.temporaryDirectory.appending(path: "profiles-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        // A comma left out between two profiles.
        try Data(#"[{ "letter": "A" } { "letter": "B" }]"#.utf8).write(to: file)
        #expect(ProfileStyle.reload(from: file) == nil)
        try Data(#"[{ "letter": "D" }]"#.utf8).write(to: file)
        #expect(ProfileStyle.reload(from: file)?.map(\.letter) == ["D"])
    }

    @Test func anUnlistedLetterIsPlainGrey() {
        #expect(ProfileStyle.of("B", in: ProfileStyle.defaults).color == "#F5822F")
        #expect(ProfileStyle.of("Q", in: ProfileStyle.defaults) == ProfileStyle(letter: "Q", label: "Claude Q", color: "#B3B3B3", hotkey: nil))
    }

    @Test func colours() throws {
        let blue = try #require(ProfileStyle.rgb("#2F7BF5"))
        #expect(blue.red == 0x2F / 255.0 && blue.green == 0x7B / 255.0 && blue.blue == 0xF5 / 255.0)
        #expect(ProfileStyle.rgb("2F7BF5") != nil)
        #expect(ProfileStyle.rgb("#2F7") == nil)
        #expect(ProfileStyle.rgb("#GGGGGG") == nil)
    }

    @Test func theTemplateInTheRepoIsTheDefaults() throws {
        // From apps/notch/Tests/UsageCoreTests up to the repo.
        let template = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "files/profiles.json")
        #expect(ProfileStyle.parse(try Data(contentsOf: template)) == ProfileStyle.defaults)
        // The settings page's Edit writes the file out the same way.
        #expect(ProfileStyle.template(ProfileStyle.defaults) == (try String(contentsOf: template, encoding: .utf8)))
    }

    @Test func aWrittenFileReadsBackTheSame() {
        let styles = [
            ProfileStyle(letter: "A", label: "Work \"main\"", color: "#2F7BF5", hotkey: "1"),
            ProfileStyle(letter: "D", label: "me@example.com / test", color: "#B3B3B3", hotkey: nil),
        ]
        #expect(ProfileStyle.parse(Data(ProfileStyle.template(styles).utf8)) == styles)
    }

    @Test func theNextCopyIsTheFirstFreeLetterWithItsOwnKey() throws {
        let next = try #require(ProfileStyle.next(after: ProfileStyle.defaults))
        #expect(next == ProfileStyle(letter: "D", label: "Claude D", color: "#B04FD6", hotkey: "4"))
        // A gap left by a removed copy is filled first; its own key is taken, so the first free one.
        let gap = [ProfileStyle.defaults[0], ProfileStyle(letter: "C", label: "C", color: "#2FB36B", hotkey: "2")]
        #expect(ProfileStyle.next(after: gap) == ProfileStyle(letter: "B", label: "Claude B", color: "#F5822F", hotkey: "3"))
        // After H, grey; after I, no key of its own.
        let nine = (65...73).map { ProfileStyle(letter: String(UnicodeScalar(UInt8($0))), label: "", color: "#000000", hotkey: nil) }
        #expect(ProfileStyle.next(after: nine) == ProfileStyle(letter: "J", label: "Claude J", color: "#B3B3B3", hotkey: "1"))
        let all = (65...90).map { ProfileStyle(letter: String(UnicodeScalar(UInt8($0))), label: "", color: "#000000", hotkey: nil) }
        #expect(ProfileStyle.next(after: all) == nil)
    }
}
