---
title: Day to day
description: Switching copies, closing windows, Claude in Chrome, the Code tab, and what the copies share.
section: Using it
order: 3
---

## Switching

- <kbd>⌥⌘1</kbd>, <kbd>⌥⌘2</kbd> and <kbd>⌥⌘3</kbd> switch to A, B and C from anywhere, starting the copy if it's closed. A peek under the notch names the copy you switched to.
- Clicking a row in the notch panel does the same.
- <kbd>⌥⌘0</kbd> switches to the copy with the most room: of those read in the last 15 minutes and not out of any limit, the one whose fullest window, 5-hour or weekly, is lowest. A tie goes to the earlier letter, and the panel's footer names it ("Most room: Claude C"). When every copy is out, the peek says **No copy has room** and which is back first, and nothing switches. A profile whose own hotkey is `0` keeps it, and a switch in [settings](/docs/settings) turns this off.
- The **outline** round the window in front, in that copy's colour, shows which Claude you're typing into.

## Closing and quitting

Closing a Claude window doesn't quit that copy: it keeps running with no window, as Mac apps do. Switching to it sends the same "reopen" message a Dock click sends, so a new window appears. To really quit a copy, press <kbd>⌘Q</kbd> in it.

## Links

When another app is in front, the next `claude://` link goes to the Claude you used last. The panel's footer says which one ("Links go to Claude B").

## What the copies share

| | Shared between copies | Separate per copy |
| --- | --- | --- |
| **Login, conversations, settings** | | Each copy's own data folder |
| **Claude in Chrome** | One Chrome, one extension, tied to your Mac user | |
| **Built-in browser pane** | | Each copy has its own site logins |
| **Code tab** | MCP servers, skills, transcripts and memory in `~/.claude` | |
| **Logs** | `~/Library/Logs/Claude/main.log` | |

- **Claude in Chrome:** every copy can use the same Chrome. Just don't have two driving it at the same time.
- **Code tab:** sharing `~/.claude` is useful, since every account sees the same skills and memory. But don't run two accounts in the same git worktree at once.

## Updates to Claude

Claude.app updates itself as normal, and every copy runs the same updated app. When an update installs, quit and reopen **all** the copies; any that didn't restart keeps running the old version.
