import Foundation

/// The Claude in Chrome tools the relay offers, with the argument names the extension
/// expects. Leaves out the ones that need Claude's own host: picking between browsers
/// (bridge only), uploading files or images from the chat, GIF recording and shortcuts.
public enum Tools {
    /// Never mutated, so safe to share although [String: Any] isn't Sendable.
    nonisolated(unsafe) public static let list = (try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]]) ?? []

    public static let names = Set(list.compactMap { $0["name"] as? String })

    static let tab = #"{ "type": "number", "description": "A tab id from tabs_context_mcp. Must be in this session's tab group." }"#

    static let json = #"""
    [
      {
        "name": "tabs_context_mcp",
        "description": "List the tabs in this session's tab group in Chrome. Call it before anything else, with createIfEmpty: true to make the group (a new window with one empty tab) if there isn't one. Every other tool needs a tab id from this list; work only in those tabs.",
        "inputSchema": { "type": "object", "properties": {
          "createIfEmpty": { "type": "boolean", "description": "Make the tab group if it doesn't exist yet." }
        } }
      },
      {
        "name": "tabs_create_mcp",
        "description": "Open a new empty tab in this session's tab group and return its id. Close tabs you open with tabs_close_mcp when you're done with them.",
        "inputSchema": { "type": "object", "properties": {} }
      },
      {
        "name": "tabs_close_mcp",
        "description": "Close a tab in this session's tab group.",
        "inputSchema": { "type": "object", "properties": { "tabId": { "type": "integer" } }, "required": ["tabId"] }
      },
      {
        "name": "navigate",
        "description": "Load a URL in a tab, or pass \"back\" or \"forward\" to move through its history. Without tabId, a URL loads in the first tab of this session's group (made if needed).",
        "inputSchema": { "type": "object", "properties": {
          "url": { "type": "string", "description": "The URL (https:// is assumed), or \"back\" or \"forward\"." },
          "tabId": TAB_SCHEMA
        }, "required": ["url"] }
      },
      {
        "name": "computer",
        "description": "Use the mouse and keyboard in a tab, or take a screenshot of it. Take a screenshot to find coordinates before clicking. Actions: left_click, right_click, double_click, triple_click, hover, left_click_drag (start_coordinate to coordinate), type (text), key (space-separated keys such as \"cmd+a Backspace\"), scroll (scroll_direction, scroll_amount) or scroll_to (ref), wait (duration, at most 10 seconds), screenshot, zoom (region, for a closer look).",
        "inputSchema": { "type": "object", "properties": {
          "action": { "type": "string", "enum": ["left_click", "right_click", "type", "screenshot", "wait", "scroll", "key", "left_click_drag", "double_click", "triple_click", "zoom", "scroll_to", "hover"] },
          "coordinate": { "type": "array", "items": { "type": "number" }, "minItems": 2, "maxItems": 2, "description": "[x, y] in the screenshot's pixels." },
          "start_coordinate": { "type": "array", "items": { "type": "number" }, "minItems": 2, "maxItems": 2 },
          "text": { "type": "string" },
          "duration": { "type": "number", "minimum": 0, "maximum": 10 },
          "scroll_direction": { "type": "string", "enum": ["up", "down", "left", "right"] },
          "scroll_amount": { "type": "number", "minimum": 1, "maximum": 10 },
          "region": { "type": "array", "items": { "type": "number" }, "minItems": 4, "maxItems": 4, "description": "[x0, y0, x1, y1] for zoom." },
          "scale": { "type": "number", "minimum": 0.1, "maximum": 1, "description": "Shrink a screenshot or zoom to save tokens." },
          "repeat": { "type": "number", "minimum": 1, "maximum": 100, "description": "Press the keys this many times." },
          "ref": { "type": "string", "description": "An element ref from read_page or find, instead of coordinates." },
          "modifiers": { "type": "string", "description": "Held during a click: ctrl, shift, alt, cmd, combined with +." },
          "tabId": TAB_SCHEMA
        }, "required": ["action", "tabId"] }
      },
      {
        "name": "read_page",
        "description": "The page's accessibility tree, with a ref for each element that other tools accept. filter \"interactive\" keeps only buttons, links and fields.",
        "inputSchema": { "type": "object", "properties": {
          "filter": { "type": "string", "enum": ["interactive", "all"] },
          "depth": { "type": "number", "description": "How deep to go (default 15)." },
          "ref_id": { "type": "string", "description": "Read only this element and what's inside it." },
          "max_chars": { "type": "number", "description": "Cut the output off here (default 50000)." },
          "tabId": TAB_SCHEMA
        }, "required": ["tabId"] }
      },
      {
        "name": "find",
        "description": "Find elements by what they are or say, such as \"search box\" or \"Add to cart button\". Returns up to 20 matches with refs.",
        "inputSchema": { "type": "object", "properties": {
          "query": { "type": "string" },
          "tabId": TAB_SCHEMA
        }, "required": ["query", "tabId"] }
      },
      {
        "name": "form_input",
        "description": "Set a form field's value by its ref from read_page or find: text for inputs, true or false for checkboxes, an option's value or text for selects.",
        "inputSchema": { "type": "object", "properties": {
          "ref": { "type": "string" },
          "value": { "type": ["string", "boolean", "number"] },
          "tabId": TAB_SCHEMA
        }, "required": ["ref", "value", "tabId"] }
      },
      {
        "name": "get_page_text",
        "description": "The page's main text, without markup.",
        "inputSchema": { "type": "object", "properties": { "tabId": TAB_SCHEMA }, "required": ["tabId"] }
      },
      {
        "name": "javascript_tool",
        "description": "Run JavaScript in the page and return the last expression's value. Top-level await works. Set action to \"javascript_exec\".",
        "inputSchema": { "type": "object", "properties": {
          "action": { "type": "string", "enum": ["javascript_exec"] },
          "text": { "type": "string", "description": "The code." },
          "tabId": TAB_SCHEMA
        }, "required": ["action", "text", "tabId"] }
      },
      {
        "name": "read_console_messages",
        "description": "The tab's console messages.",
        "inputSchema": { "type": "object", "properties": {
          "onlyErrors": { "type": "boolean" },
          "pattern": { "type": "string", "description": "Only messages matching this." },
          "limit": { "type": "number" },
          "clear": { "type": "boolean", "description": "Forget them after reading." },
          "tabId": TAB_SCHEMA
        }, "required": ["tabId"] }
      },
      {
        "name": "read_network_requests",
        "description": "The tab's network requests.",
        "inputSchema": { "type": "object", "properties": {
          "urlPattern": { "type": "string", "description": "Only URLs containing this." },
          "limit": { "type": "number" },
          "clear": { "type": "boolean", "description": "Forget them after reading." },
          "tabId": TAB_SCHEMA
        }, "required": ["tabId"] }
      },
      {
        "name": "resize_window",
        "description": "Resize the window a tab is in.",
        "inputSchema": { "type": "object", "properties": {
          "width": { "type": "number" },
          "height": { "type": "number" },
          "tabId": TAB_SCHEMA
        }, "required": ["width", "height", "tabId"] }
      },
      {
        "name": "browser_batch",
        "description": "Run several of these tools in one round trip, in order, stopping at the first error. Each action is {name, input}, with input as you'd pass to that tool. Much faster than separate calls for a known sequence of clicks, typing and screenshots.",
        "inputSchema": { "type": "object", "properties": {
          "actions": { "type": "array", "minItems": 1, "items": { "type": "object", "properties": {
            "name": { "type": "string" },
            "input": { "type": "object" }
          }, "required": ["name", "input"] } }
        }, "required": ["actions"] }
      }
    ]
    """#.replacingOccurrences(of: "TAB_SCHEMA", with: tab)
}
