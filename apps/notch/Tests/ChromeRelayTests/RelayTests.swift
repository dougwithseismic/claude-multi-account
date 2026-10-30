import Foundation
import Testing
@testable import ChromeRelay

@Suite struct FrameTests {
    @Test func roundTripsAndWaitsForWholeFrames() throws {
        let first = Data(#"{"a":1}"#.utf8)
        let second = Data(#"{"b":[2,3]}"#.utf8)
        let stream = Frame.encode(first) + Frame.encode(second)
        #expect(Array(stream.prefix(4)) == [7, 0, 0, 0])

        var buffer = stream.prefix(9)
        #expect(Frame.take(from: &buffer) == nil)
        buffer = Data(stream)
        #expect(Frame.take(from: &buffer) == first)
        #expect(Frame.take(from: &buffer) == second)
        #expect(Frame.take(from: &buffer) == nil)
        #expect(buffer.isEmpty)
    }

    @Test func readsFromASlice() throws {
        // Data that has had bytes removed from the front no longer starts at index 0.
        var buffer = Data([0xFF]) + Frame.encode(Data("{}".utf8))
        buffer = buffer.dropFirst()
        #expect(Frame.take(from: &buffer) == Data("{}".utf8))
    }
}

@Suite struct RelayRequestTests {
    @Test func scopesEveryCallToTheSession() throws {
        let relay = Relay(sessionID: "s-1", displayName: "Claude B")
        let request = relay.request("get_page_text", arguments: ["tabId": 7], toolUseID: "t-1")
        #expect(request["method"] as? String == "execute_tool")
        let params = try #require(request["params"] as? [String: Any])
        #expect(params["tool"] as? String == "get_page_text")
        #expect(params["tool_use_id"] as? String == "t-1")
        #expect(params["args"] as? [String: Int] == ["tabId": 7])
        #expect(params["session_scope"] as? [String: String] == ["sessionId": "s-1", "displayName": "Claude B"])
    }

    @Test func readsTheTabGroupFromTheContext() throws {
        let response: [String: Any] = ["result": ["content": [
            ["type": "text", "text": #"{"availableTabs":[{"tabId":41,"title":"New Tab","url":"chrome://newtab/"}],"tabGroupId":9}"#],
            ["type": "text", "text": "\n\nTab Context: …"],
        ]], "tool_use_id": "t-1"]
        #expect(Relay.tabGroup(in: response) == 9)
        #expect(Relay.tabGroup(in: ["result": ["content": [["type": "text", "text": "Navigated"]]]]) == nil)
    }
}

@Suite struct ToolResultTests {
    @Test func turnsMessagesImagesIntoMCPImages() throws {
        let result = Relay.toolResult(from: ["result": ["content": [
            ["type": "text", "text": "Took a screenshot"],
            ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": "QUJD"]],
        ]]])
        #expect(result["isError"] as? Bool == false)
        let content = try #require(result["content"] as? [[String: Any]])
        #expect(content[0]["text"] as? String == "Took a screenshot")
        #expect(content[1] as? [String: String] == ["type": "image", "data": "QUJD", "mimeType": "image/jpeg"])
    }

    @Test func marksErrorsAndWrapsPlainText() throws {
        let result = Relay.toolResult(from: ["error": ["content": "No tab available"]])
        #expect(result["isError"] as? Bool == true)
        #expect((result["content"] as? [[String: Any]])?.first?["text"] as? String == "No tab available")
        let empty = Relay.toolResult(from: ["result": [:]])
        #expect((empty["content"] as? [[String: Any]])?.first?["text"] as? String == "Tool execution completed")
    }
}

@Suite struct ToolsTests {
    @Test func everyToolHasASchemaAndTheTabArgumentIsFilledIn() throws {
        let tools = Tools.list
        #expect(tools.count == 14)
        for tool in tools {
            let schema = try #require(tool["inputSchema"] as? [String: Any])
            #expect(schema["type"] as? String == "object")
        }
        #expect(!Tools.json.contains("TAB_SCHEMA"))
        #expect(Tools.names.isSuperset(of: ["tabs_context_mcp", "navigate", "computer", "browser_batch"]))
    }
}
