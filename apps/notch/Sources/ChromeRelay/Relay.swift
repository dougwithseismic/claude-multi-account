import Foundation

/// Sends Claude in Chrome tool calls to the extension through its local native host
/// instead of Anthropic's bridge. The bridge pairs a Claude app with the extension by
/// claude.ai account, so a Chrome profile serves one account; the local host doesn't
/// look at accounts, so every copy of Claude can use the same profile this way.
///
/// Each relay is one session: the extension gives it its own tab group, named after the
/// copy ("Claude B"), and the relay passes that group's id along with every call.
public final class Relay {
    /// The session the extension files this relay's tabs under.
    let sessionID: String
    let displayName: String
    private(set) var tabGroupID: Int?

    private let socketPath: String?
    private var connection: HostConnection?
    private let timeout: TimeInterval = 120

    public init(sessionID: String, displayName: String, socketPath: String? = nil) {
        self.sessionID = sessionID
        self.displayName = displayName
        self.socketPath = socketPath
    }

    /// Runs `tool` and returns an MCP tool result.
    public func call(_ tool: String, arguments: [String: Any]) -> [String: Any] {
        do {
            // A call without a tab id works in the first tab of this session's group, so
            // make the group first if there isn't one yet.
            if tabGroupID == nil, tool != "tabs_context_mcp" {
                let context = try run("tabs_context_mcp", arguments: ["createIfEmpty": true])
                if context["error"] != nil { return Self.toolResult(from: context) }
            }
            return Self.toolResult(from: try run(tool, arguments: arguments))
        } catch {
            return Self.errorResult(error.description)
        }
    }

    /// Sends one call and returns the extension's answer, keeping the tab group that
    /// tabs_context_mcp reports.
    private func run(_ tool: String, arguments: [String: Any]) throws(RelayError) -> [String: Any] {
        let toolUseID = UUID().uuidString.lowercased()
        let response = try exchange(request(tool, arguments: arguments, toolUseID: toolUseID), toolUseID: toolUseID)
        if tool == "tabs_context_mcp", let group = Self.tabGroup(in: response) { tabGroupID = group }
        return response
    }

    /// The frame the native host expects for one tool call.
    func request(_ tool: String, arguments: [String: Any], toolUseID: String) -> [String: Any] {
        var arguments = arguments
        if let tabGroupID { arguments["tabGroupId"] = tabGroupID }
        return [
            "method": "execute_tool",
            "params": [
                "client_id": "claude-code",
                "tool": tool,
                "args": arguments,
                "tool_use_id": toolUseID,
                "session_scope": ["sessionId": sessionID, "displayName": displayName],
            ] as [String: Any],
        ]
    }

    /// Sends `request` and waits for its answer. A connection that has gone stale since the
    /// last call (Chrome restarted) is replaced once, before anything is sent.
    private func exchange(_ request: [String: Any], toolUseID: String) throws(RelayError) -> [String: Any] {
        let body: Data
        do { body = try JSONSerialization.data(withJSONObject: request) } catch { throw .io("unencodable arguments") }

        var connection = try openConnection()
        do {
            try connection.send(body)
        } catch {
            self.connection = nil
            connection = try openConnection()
            try connection.send(body)
        }
        while true {
            let frame = try connection.receive(timeout: timeout)
            guard let message = try? JSONSerialization.jsonObject(with: frame) as? [String: Any] else { continue }
            // Skip notifications and answers to earlier calls that timed out.
            guard message["result"] != nil || message["error"] != nil else { continue }
            if let id = message["tool_use_id"] as? String, id != toolUseID { continue }
            return message
        }
    }

    /// The open connection, or a new one to the newest live host. One the host hung up on
    /// shows as not open, so it's replaced here.
    private func openConnection() throws(RelayError) -> HostConnection {
        if let connection, connection.isOpen { return connection }
        connection = nil
        let paths = if let socketPath { [socketPath] } else { try HostSocket.live() }
        var lastError = RelayError.noHost
        for path in paths {
            do {
                let opened = try HostConnection(path: path)
                connection = opened
                return opened
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    // MARK: - Reading answers

    /// The extension's answer as an MCP tool result. Its images are in the Messages API's
    /// shape ({source: {data, media_type}}); MCP wants {data, mimeType}.
    static func toolResult(from response: [String: Any]) -> [String: Any] {
        guard let payload = (response["error"] ?? response["result"]) as? [String: Any], let content = payload["content"] else {
            return ["content": [["type": "text", "text": "Tool execution completed"]]]
        }
        let blocks = content as? [Any] ?? ["\(content)"]
        let converted = blocks.map { block -> [String: Any] in
            guard let block = block as? [String: Any], let type = block["type"] as? String else {
                return ["type": "text", "text": "\(block)"]
            }
            if type == "image", let source = block["source"] as? [String: Any], let data = source["data"] as? String {
                return ["type": "image", "data": data, "mimeType": source["media_type"] as? String ?? "image/png"]
            }
            return block
        }
        return ["content": converted, "isError": response["error"] != nil]
    }

    public static func errorResult(_ message: String) -> [String: Any] {
        ["content": [["type": "text", "text": message]], "isError": true]
    }

    /// The tab group tabs_context_mcp reports in its first block:
    /// {"availableTabs":[…],"tabGroupId":123}.
    static func tabGroup(in response: [String: Any]) -> Int? {
        guard let blocks = (response["result"] as? [String: Any])?["content"] as? [[String: Any]],
              let text = blocks.first?["text"] as? String,
              let context = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return nil }
        return context["tabGroupId"] as? Int
    }
}
