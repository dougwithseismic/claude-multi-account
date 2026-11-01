---
title: How it works
description: Why each copy of Claude stays signed in on its own, and the two problems Claude Notch solves to make that work.
section: Help
order: 13
---

## One data folder per account

Claude is an Electron app. Electron keeps everything for one account (login, settings, window state) in a single data folder, `~/Library/Application Support/Claude`. Start Claude with `--user-data-dir=<another folder>` and that copy runs separately, with its own login.

So Claude A uses the usual folder, and Claude B uses `Claude-B`. The app is the same `/Applications/Claude.app` each time, unmodified, so every copy updates with it.

## Two catches

1. **Claude doesn't stop a duplicate.** Opening Claude again while a copy is running on the same folder starts a second copy on that folder, and two copies on one folder can corrupt it. The launchers (`files/claude-profile.sh` inside each `Claude X.app`) bring an open copy to the front instead of starting another.
2. **macOS sends every `claude://` link to the copy that started first.** That includes the sign-in link, so on its own, signing in to B would try to sign in A instead. Claude Notch takes those links and passes each to the copy you used last. It takes them when it starts, and again whenever a copy of Claude starts, in case a Claude update took them back.

## Which copy is which

Claude Notch reads each running Claude's `--user-data-dir` from the system (none, or `…/Claude`, is A; `…/Claude-B` is B). Activation notifications give the copy in front and the one used last. The hotkeys are registered with the system, and the outline is a click-through window drawn round the front Claude's window. None of this needs Accessibility permission.

## Where the numbers come from

Each copy keeps its login in its `config.json`, encrypted with the Claude Safe Storage key. Claude Notch decrypts it in memory, picks the login for each organization the account belongs to, and asks Anthropic's usage endpoint for that organization's limits, the same request Claude Code's `/usage` makes. [Privacy and security](/docs/privacy) lists exactly what's read and sent.

## Claude in Chrome for every copy

The Claude in Chrome extension runs a small helper on your Mac, a "native host" that Chrome starts with it and that listens on a socket in `/tmp/claude-mcp-browser-bridge-<you>/`. Claude's own apps mostly reach the extension through Anthropic's servers, paired by claude.ai account. The helper takes the same tool calls locally and doesn't check the account.

[`claude-chrome-relay`](/docs/chrome) is an MCP server that speaks that local protocol. It checks the socket's folder belongs to you and is closed to other users, as Claude does, then sends each tool call with a session of its own, so the extension gives every Code session its own tab group. It finds its copy the way the notch does, from the Claude process above it (or `CLAUDE_CONFIG_DIR` for `claude-b`), names the group after it, and tells the notch which copy just used Chrome.

The full design, with the research behind each choice, is in the [app's design document](https://github.com/dougwithseismic/claude-multi-account/blob/main/docs/notch-prd.md).
