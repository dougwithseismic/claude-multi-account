import Foundation
import Testing
@testable import UsageCore

private let command = "'/Users/me/My Repos/claude-multi-account/apps/notch/build/claude-usage' --statusline"

private func added(_ text: String?) throws -> String {
    guard case .added(let result) = StatusLineSetting.add(command: command, to: text) else {
        Issue.record("not added: \(StatusLineSetting.add(command: command, to: text))")
        return ""
    }
    return result
}

private func object(_ text: String) throws -> [String: Any] {
    try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
}

@Suite struct StatusLineSettingTests {
    @Test func addedAfterTheLastSettingWithTheFilesIndent() throws {
        let before = """
        {
          "model": "opus",
          "permissions": {
            "allow": ["Bash(git status)", "Read(~/notes/**)"]
          },
          "env": { "FOO": "a \\"quoted\\" }, value" }
        }

        """
        let after = try added(before)
        #expect(after == """
        {
          "model": "opus",
          "permissions": {
            "allow": ["Bash(git status)", "Read(~/notes/**)"]
          },
          "env": { "FOO": "a \\"quoted\\" }, value" },
          "statusLine": {
            "type": "command",
            "command": "'/Users/me/My Repos/claude-multi-account/apps/notch/build/claude-usage' --statusline",
            "refreshInterval": 60
          }
        }

        """)
        let statusLine = try #require(try object(after)["statusLine"] as? [String: Any])
        #expect(statusLine["type"] as? String == "command")
        #expect(statusLine["command"] as? String == command)
        #expect(statusLine["refreshInterval"] as? Int == 60)
    }

    @Test func everythingElseStaysByteForByte() throws {
        let before = "{\n\t\"z\": 1,\n\t\"a\": [1, 2,   3],\n\t\"hooks\": {\"PreToolUse\": []}\n}"
        let after = try added(before)
        // Only an insertion before the closing brace.
        let insertedAt = try #require(before.range(of: "\n}", options: .backwards)).lowerBound
        #expect(after.hasPrefix(String(before[..<insertedAt])))
        #expect(after.hasSuffix("\n}"))
        #expect(after.contains(",\n\t\"statusLine\": {\n\t\t\"type\": \"command\",\n"))
        #expect(NSDictionary(dictionary: try object(after).filter { $0.key != "statusLine" }).isEqual(to: try object(before)))
    }

    @Test func aFileOnOneLineStaysOnOne() throws {
        let after = try added(#"{"model":"opus","theme":"dark"}"#)
        #expect(after == #"{"model":"opus","theme":"dark", "statusLine": { "type": "command", "command": "'/Users/me/My Repos/claude-multi-account/apps/notch/build/claude-usage' --statusline", "refreshInterval": 60 }}"#)
    }

    @Test func anEmptyOrMissingFileGetsJustTheStatusLine() throws {
        let fresh = """
        {
          "statusLine": {
            "type": "command",
            "command": "'/Users/me/My Repos/claude-multi-account/apps/notch/build/claude-usage' --statusline",
            "refreshInterval": 60
          }
        }

        """
        #expect(try added(nil) == fresh)
        #expect(try added("") == fresh)
        #expect(try added("  \n") == fresh)
        #expect(try added("{}") == "{\n  \"statusLine\": {\n    \"type\": \"command\",\n    \"command\": \"'/Users/me/My Repos/claude-multi-account/apps/notch/build/claude-usage' --statusline\",\n    \"refreshInterval\": 60\n  }\n}")
        #expect(try added("{ }\n").hasSuffix("\n  }\n}\n"))
    }

    @Test func anotherStatusLineIsNeverReplaced() throws {
        let theirs = #"{"statusLine": {"type": "command", "command": "~/.claude/statusline.sh", "padding": 0}, "model": "opus"}"#
        guard case .other(let existing) = StatusLineSetting.add(command: command, to: theirs) else {
            Issue.record("replaced")
            return
        }
        #expect(existing.contains("~/.claude/statusline.sh"))
        #expect(existing.contains("\"padding\" : 0"))
        // Not even a status line that isn't an object.
        #expect(StatusLineSetting.add(command: command, to: #"{"statusLine": "x"}"#) == .other("\"x\""))
        // And taking ours out leaves theirs.
        #expect(StatusLineSetting.remove(from: theirs) == nil)
    }

    @Test func oursIsLeftAsItIs() {
        let ours = #"{"statusLine": {"type": "command", "command": "/elsewhere/claude-usage --statusline --only A,B"}}"#
        #expect(StatusLineSetting.add(command: command, to: ours) == .alreadyOurs)
    }

    @Test func aFileThatIsntAnObjectIsLeftAlone() {
        for text in ["[1, 2]", "{\"a\": 1,}", "// comment\n{}", "{\"a\": 1} trailing", "not json"] {
            guard case .unreadable = StatusLineSetting.add(command: command, to: text) else {
                Issue.record("edited \(text)")
                continue
            }
        }
    }

    @Test func aByteOrderMarkAndOddSpacingAreFollowed() throws {
        let before = "\u{FEFF}{ \"a\" : { \"b\" : [ \"}\" , \"\\\\\" ] } , \"c\":null }"
        let after = try added(before)
        #expect(after.hasPrefix("\u{FEFF}{ \"a\" : { \"b\" : [ \"}\" , \"\\\\\" ] } , \"c\":null, \"statusLine\": {"))
        #expect(try object(String(after.dropFirst()))["c"] is NSNull)
    }

    @Test func removingTakesOutOnlyOurs() throws {
        let original = "{\n  \"model\": \"opus\",\n  \"env\": {}\n}\n"
        let withOurs = try added(original)
        #expect(StatusLineSetting.remove(from: withOurs) == original)

        // First of several, in the middle, or alone.
        let first = #"{"statusLine": {"command": "claude-usage --statusline"}, "a": 1, "b": 2}"#
        #expect(StatusLineSetting.remove(from: first) == #"{"a": 1, "b": 2}"#)
        let middle = #"{"a": 1, "statusLine": {"command": "claude-usage --statusline"}, "b": 2}"#
        #expect(StatusLineSetting.remove(from: middle) == #"{"a": 1, "b": 2}"#)
        #expect(StatusLineSetting.remove(from: try added("{}")) == "{\n}")
        #expect(StatusLineSetting.remove(from: #"{"statusLine": {"command": "claude-usage --statusline"}}"#) == "{}")
        #expect(StatusLineSetting.remove(from: #"{"a": 1}"#) == nil)
    }

    @Test func writingKeepsTheFilesModeAndALinkStaysALink() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "statusline-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let real = folder.appending(path: "dotfiles/settings.json")
        let link = folder.appending(path: ".claude/settings.json")
        try FileManager.default.createDirectory(at: real.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: real)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: real.path(percentEncoded: false))
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        try StatusLineSetting.write(try added("{}"), to: link)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path(percentEncoded: false)) == real.path(percentEncoded: false))
        #expect(try String(contentsOf: real, encoding: .utf8).contains("claude-usage"))
        #expect(try FileManager.default.attributesOfItem(atPath: real.path(percentEncoded: false))[.posixPermissions] as? Int == 0o600)
        // Nothing left beside it.
        #expect(try FileManager.default.contentsOfDirectory(atPath: real.deletingLastPathComponent().path(percentEncoded: false)) == ["settings.json"])

        // A new file, in a folder that isn't there yet.
        let new = folder.appending(path: "new/.claude/settings.json")
        try StatusLineSetting.write(try added(nil), to: new)
        #expect(try FileManager.default.attributesOfItem(atPath: new.path(percentEncoded: false))[.posixPermissions] as? Int == 0o644)
    }
}
