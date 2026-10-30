import ChromeRelay
import Foundation
import UsageCore

// claude-chrome-relay [--label "Claude B"] [--socket <path>]
// An MCP server (stdio) with the Claude in Chrome tools, for any copy of Claude; see Relay.
// --label names the tab group (default: the copy's name). --socket picks a native host
// when several browsers run the extension (default: the newest).

let usageLine = "usage: claude-chrome-relay [--label <name>] [--socket <path>]"

func badArguments(_ message: String) -> Never {
    FileHandle.standardError.write(Data("claude-chrome-relay: \(message)\n\(usageLine)\n".utf8))
    exit(2)
}

var label: String?
var socketPath: String?
var arguments = CommandLine.arguments.dropFirst()
while let argument = arguments.popFirst() {
    switch argument {
    case "-h", "--help":
        print(usageLine)
        exit(0)
    case "--label":
        guard let value = arguments.popFirst(), !value.isEmpty else { badArguments("--label takes a name") }
        label = value
    case "--socket":
        guard let value = arguments.popFirst(), !value.isEmpty else { badArguments("--socket takes a path") }
        socketPath = value
    default:
        badArguments("unknown argument \(argument)")
    }
}

// A Code tab session passes its id down, so each conversation gets its own tab group.
let environment = ProcessInfo.processInfo.environment
let sessionID = environment["CLAUDE_CODE_SESSION_ID"].flatMap(UUID.init(uuidString:)) ?? UUID()
let name = label ?? ClaudeProcess.copy().map { ProfileStyle.of($0, in: ProfileStyle.load()).label } ?? "Claude"
let relay = Relay(sessionID: sessionID.uuidString.lowercased(), displayName: name, socketPath: socketPath)

/// Answers request `id` with `body`: ["result": …] or ["error": …].
func reply(_ id: Any, _ body: [String: Any]) {
    let message = body.merging(["jsonrpc": "2.0", "id": id]) { _, new in new }
    // Screenshots are base64, full of "/", which needn't be escaped.
    guard var data = try? JSONSerialization.data(withJSONObject: message, options: .withoutEscapingSlashes) else { return }
    data.append(UInt8(ascii: "\n"))
    FileHandle.standardOutput.write(data)
}

// One JSON-RPC message per line. Calls run one at a time, as the host answers one
// request per connection at a time.
while let line = readLine() {
    guard let message = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
          let method = message["method"] as? String else { continue }
    // Notifications (initialized, cancelled) need no answer.
    guard let id = message["id"] else { continue }
    let params = message["params"] as? [String: Any] ?? [:]

    switch method {
    case "initialize":
        reply(id, ["result": [
            "protocolVersion": params["protocolVersion"] as? String ?? "2025-06-18",
            "capabilities": ["tools": [:]],
            "serverInfo": ["name": "claude-chrome-relay", "version": "0.1.0"],
            "instructions": "Browser tools for the Chrome on this Mac, through the Claude in Chrome extension. Start with tabs_context_mcp (createIfEmpty: true) to get this session's tab group, and work only in its tabs.",
        ]])
    case "ping":
        reply(id, ["result": [:]])
    case "tools/list":
        reply(id, ["result": ["tools": Tools.list]])
    case "tools/call":
        guard let name = params["name"] as? String else {
            reply(id, ["error": ["code": -32602, "message": "tools/call needs a name"]])
            continue
        }
        guard Tools.names.contains(name) else {
            reply(id, ["result": Relay.errorResult("Unknown tool: \(name)")])
            continue
        }
        reply(id, ["result": relay.call(name, arguments: params["arguments"] as? [String: Any] ?? [:])])
    default:
        reply(id, ["error": ["code": -32601, "message": "Method not found: \(method)"]])
    }
}
