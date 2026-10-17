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
        let template = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
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
}
