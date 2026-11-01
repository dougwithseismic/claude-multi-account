import Darwin
import Foundation
import Testing
@testable import ChromeRelay

/// Stands in for Chrome's native host: a Unix socket that answers each framed request with
/// whatever `answer` returns, echoing its tool_use_id.
final class FakeHost: @unchecked Sendable {
    let path = "/tmp/cnr-\(UUID().uuidString.prefix(8)).sock"
    private let listener: Int32
    private let lock = NSLock()
    private var requests: [[String: Any]] = []
    private let answer: @Sendable (_ tool: String, _ args: [String: Any]) -> [String: Any]

    init(answer: @escaping @Sendable (_ tool: String, _ args: [String: Any]) -> [String: Any]) throws {
        self.answer = answer
        listener = socket(AF_UNIX, SOCK_STREAM, 0)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: Array(path.utf8)) }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, listen(listener, 4) == 0 else { throw POSIXError(.EADDRINUSE) }
        Thread.detachNewThread { [self] in serve() }
    }

    deinit {
        close(listener)
        unlink(path)
    }

    /// The tools called so far, in order.
    var tools: [String] { lock.withLock { requests.compactMap { ($0["params"] as? [String: Any])?["tool"] as? String } } }

    /// The tab group each call carried.
    var groups: [Int?] { lock.withLock { requests.map { (($0["params"] as? [String: Any])?["args"] as? [String: Any])?["tabGroupId"] as? Int } } }

    private func serve() {
        let client = accept(listener, nil, nil)
        guard client >= 0 else { return }
        defer { close(client) }
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while true {
            while let body = Frame.take(from: &buffer) {
                guard let request = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                      let params = request["params"] as? [String: Any] else { continue }
                lock.withLock { requests.append(request) }
                var response = answer(params["tool"] as? String ?? "", params["args"] as? [String: Any] ?? [:])
                response["tool_use_id"] = params["tool_use_id"]
                let frame = Frame.encode(try! JSONSerialization.data(withJSONObject: response))
                _ = frame.withUnsafeBytes { write(client, $0.baseAddress!, frame.count) }
            }
            let n = read(client, &chunk, chunk.count)
            guard n > 0 else { return }
            buffer.append(contentsOf: chunk[..<n])
        }
    }
}

/// A Chrome whose tab groups can be closed under the relay: tabs_context_mcp makes group 1,
/// then 2 and so on; any other call fails with "No tab available" unless it carries the
/// group that's open.
final class Groups: @unchecked Sendable {
    private let lock = NSLock()
    private var next = 1
    private var open: Int?

    func closeAll() { lock.withLock { open = nil } }

    func answer(_ tool: String, _ args: [String: Any]) -> [String: Any] {
        lock.withLock {
            if tool == "tabs_context_mcp" {
                if open == nil, args["createIfEmpty"] as? Bool == true { open = next; next += 1 }
                let group = open.map { #","tabGroupId":\#($0)"# } ?? ""
                return ["result": ["content": [["type": "text", "text": #"{"availableTabs":[]\#(group)}"#]]]]
            }
            guard let open, args["tabGroupId"] as? Int == open else {
                return ["error": ["content": [["type": "text", "text": "No tab available"]]]]
            }
            if tool == "tabs_close_mcp" {
                self.open = nil
                return ["result": ["content": [["type": "text", "text": "Closed tab 5. Group is now empty (auto-removed)."]]]]
            }
            return ["result": ["content": [["type": "text", "text": "\(tool) done"]]]]
        }
    }
}

private func text(_ result: [String: Any]) -> String? {
    (result["content"] as? [[String: Any]])?.first?["text"] as? String
}

@Suite(.serialized) struct RecoveryTests {
    @Test func aCallWithoutATabMakesANewGroupWhenTheOldOneHasGone() throws {
        let chrome = Groups()
        let host = try FakeHost { chrome.answer($0, $1) }
        let relay = Relay(sessionID: "s", displayName: "Claude B", socketPath: host.path)

        #expect(text(relay.call("navigate", arguments: ["url": "a.com"])) == "navigate done")
        chrome.closeAll() // the user closed the group in Chrome
        let result = relay.call("navigate", arguments: ["url": "b.com"])
        #expect(result["isError"] as? Bool == false)
        #expect(text(result) == "navigate done")
        #expect(host.tools == ["tabs_context_mcp", "navigate", "navigate", "tabs_context_mcp", "navigate"])
        #expect(host.groups.last == 2)
    }

    @Test func aCallForATabOrABatchIsNeverRepeated() throws {
        let chrome = Groups()
        let host = try FakeHost { chrome.answer($0, $1) }
        let relay = Relay(sessionID: "s", displayName: "Claude B", socketPath: host.path)
        _ = relay.call("tabs_context_mcp", arguments: ["createIfEmpty": true])
        chrome.closeAll()

        #expect(relay.call("get_page_text", arguments: ["tabId": 5])["isError"] as? Bool == true)
        #expect(relay.call("browser_batch", arguments: ["actions": []])["isError"] as? Bool == true)
        #expect(host.tools == ["tabs_context_mcp", "get_page_text", "browser_batch"])
    }

    @Test func closingTheLastTabForgetsTheGroup() throws {
        let chrome = Groups()
        let host = try FakeHost { chrome.answer($0, $1) }
        let relay = Relay(sessionID: "s", displayName: "Claude B", socketPath: host.path)
        _ = relay.call("tabs_context_mcp", arguments: ["createIfEmpty": true])
        _ = relay.call("tabs_close_mcp", arguments: ["tabId": 5])
        #expect(relay.tabGroupID == nil)

        // The next call makes a group first instead of failing once.
        #expect(text(relay.call("tabs_create_mcp", arguments: [:])) == "tabs_create_mcp done")
        #expect(host.tools == ["tabs_context_mcp", "tabs_close_mcp", "tabs_context_mcp", "tabs_create_mcp"])
    }

    @Test func noHelperIsAToolErrorNotACrash() {
        let relay = Relay(sessionID: "s", displayName: "Claude B", socketPath: "/tmp/cnr-missing.sock")
        let result = relay.call("navigate", arguments: ["url": "a.com"])
        #expect(result["isError"] as? Bool == true)
        #expect(text(result)?.contains("Couldn't talk to Chrome's local helper") == true)
    }
}

@Suite struct AnswerTextTests {
    @Test func readsBlocksOrAPlainString() {
        #expect(Relay.text(of: ["error": ["content": "No tab available"]]) == "No tab available")
        #expect(Relay.text(of: ["result": ["content": [["type": "text", "text": "a"], ["type": "image"], ["type": "text", "text": "b"]]]]) == "a\nb")
        #expect(Relay.text(of: ["result": [:]]) == "")
        #expect(Relay.foundNoTab(["error": ["content": "No tab available"]]))
        #expect(!Relay.foundNoTab(["result": ["content": "No tab available"]]))
    }

    @Test func onlyCallsWithoutATabAreRetried() {
        #expect(Relay.retriesInNewGroup("navigate", arguments: ["url": "a"]))
        #expect(Relay.retriesInNewGroup("tabs_create_mcp", arguments: [:]))
        #expect(!Relay.retriesInNewGroup("navigate", arguments: ["url": "a", "tabId": 3]))
        #expect(!Relay.retriesInNewGroup("browser_batch", arguments: ["actions": []]))
        #expect(!Relay.retriesInNewGroup("tabs_context_mcp", arguments: [:]))
    }
}

@Suite struct HostCheckTests {
    @Test func aMissingSocketIsNotReady() {
        #expect(!HostCheck.run(socketPath: "/tmp/cnr-missing.sock").ready)
    }

    @Test func aListeningSocketIsReady() throws {
        let host = try FakeHost { _, _ in [:] }
        #expect(HostCheck.run(socketPath: host.path).ready)
    }
}
