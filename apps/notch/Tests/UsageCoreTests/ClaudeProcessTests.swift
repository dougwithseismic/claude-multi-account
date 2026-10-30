import Foundation
import Testing
@testable import UsageCore

@Suite struct ClaudeProcessTests {
    @Test func aCopysLetterComesFromItsDataFolder() {
        let support = "/Users/me/Library/Application Support"
        #expect(ClaudeProcess.letter(fromArguments: ["/Applications/Claude.app/Contents/MacOS/Claude"]) == "A")
        #expect(ClaudeProcess.letter(fromArguments: ["Claude", "--user-data-dir=\(support)/Claude-B"]) == "B")
        #expect(ClaudeProcess.letter(fromArguments: ["Claude", "--user-data-dir=\(support)/Claude-C/"]) == "C")
        #expect(ClaudeProcess.letter(fromArguments: ["Claude", "--user-data-dir=\(support)/Claude"]) == "A")
        // Started some other way: not one of ours.
        #expect(ClaudeProcess.letter(fromArguments: ["Claude", "--user-data-dir=/tmp/scratch"]) == nil)
        #expect(ClaudeProcess.letter(fromArguments: ["Claude", "--user-data-dir=\(support)/Claude-b"]) == nil)
    }

    @Test func readsAProcesssArguments() throws {
        let mine = try #require(ClaudeProcess.arguments(of: ProcessInfo.processInfo.processIdentifier))
        #expect(mine == CommandLine.arguments)
        // argc, the executable, padding, the arguments, then the environment.
        var bytes = withUnsafeBytes(of: Int32(2)) { Array($0) }
        bytes += Array("/bin/x\0\0\0x\0--user-data-dir=/a/Claude-D\0HOME=/Users/me\0".utf8)
        #expect(ClaudeProcess.parseArguments(bytes) == ["x", "--user-data-dir=/a/Claude-D"])
        #expect(ClaudeProcess.parseArguments([1, 0]) == nil)
    }

    @Test func findsTheCopyAmongAProcesssAncestors() {
        let app = "/Applications/Claude.app/Contents/MacOS/Claude"
        let code = "/Users/me/Library/Application Support/Claude-D/claude-code/2.1.308/x/claude.app/Contents/MacOS/claude"
        let chain = [["relay"], [code, "--output-format", "stream-json"], ["/Applications/Claude.app/Contents/Helpers/disclaimer"],
                     [app, "--user-data-dir=/Users/me/Library/Application Support/Claude-D"]]
        #expect(ClaudeProcess.copy(amongAncestors: chain) == "D")
        #expect(ClaudeProcess.copy(amongAncestors: [["relay"], [app]]) == "A")
        #expect(ClaudeProcess.copy(amongAncestors: [["relay"], [code], ["/bin/zsh"]]) == nil)
        #expect(ClaudeProcess.parent(of: getpid()) == getppid())
    }
}
