---
title: Claude in Chrome in every copy
description: claude-chrome-relay gives every copy's Code sessions the Claude in Chrome tools, through your usual Chrome profile, each session in its own tab group.
section: Using it
order: 10
---

Claude in Chrome pairs the Claude app with the extension by account: the extension in a Chrome profile is signed in to one claude.ai account, and only copies on that account can use it. `claude-chrome-relay` gives every copy's Code sessions the same browser tools anyway. It's an MCP server that sends them to the extension through the small helper the extension runs on your Mac, which doesn't look at the account. So every copy can work in your usual Chrome profile, with its logins, at the same time.

## Set it up

```bash
~/claude-multi-account/install.sh --chrome
```

This adds `claude-chrome-relay` to Claude Code as a user-wide MCP server called `chrome-relay`. Every desktop copy's Code tab reads the same `~/.claude.json`, so one entry covers them all. If you've made [`claude-b`, `claude-c`…](/docs/claude-code), each of their folders gets it too.

New Code sessions then have its tools: `mcp__chrome-relay__navigate`, `computer`, `read_page`, `find`, `form_input`, `get_page_text`, `javascript_tool`, the console and network readers, tab tools and `browser_batch`. Sessions that were already open need restarting.

You need Chrome open with the Claude extension installed. The extension starts its helper when Chrome starts.

`install.sh` is safe to run again. A `chrome-relay` that runs an older checkout's relay is moved to this one; a different MCP server that happens to have that name is left alone. A plain `./install.sh` keeps the relay up to date once it's set up, and `--uninstall` takes it out of every folder it added it to.

## How sessions share Chrome

Each Code session gets its own tab group in Chrome, named after its copy ("Claude B"), and sees only its own tabs. Two sessions in different copies can work side by side without touching each other's pages. `claude-b` and the other terminal commands are named after their copy too.

If a group goes away (you closed its last tab, or Chrome restarted), the next call that doesn't name a tab makes a new group and carries on. A call that names a tab from the old group says so, and the session asks for its tabs again.

## Turn it off

**Chrome access for every copy** in [Claude Notch's settings](/docs/settings) switches it off for all copies at once. While it's off, the relay refuses every call and nothing reaches Chrome. Sessions already running see the change on their next call.

The switch is a file, so a shell can flip it too:

```bash
touch ~/.config/claude-multi-account/chrome-off
```

```bash
rm ~/.config/claude-multi-account/chrome-off
```

While access is on, a globe beside a copy's name in the panel shows that copy used Chrome in the last minute.

## Check it

```bash
~/claude-multi-account/apps/notch/build/claude-chrome-relay --check
```

It says whether Chrome's helper is running and whether access is on, and exits 0 when the relay can work. [`install.sh --doctor`](/docs/troubleshooting#check-the-setup) runs the same check, and also says which folders have the relay and whether it's up to date. Neither connects to Chrome or sends anything.

What went wrong in a session, if anything, is in the system log beside the app's, without the pages or what was typed:

```bash
log show --predicate 'subsystem == "com.godzillaaa.claude-notch" AND category == "chrome-relay"' --last 1h --info
```

## Good to know

- If several Chrome profiles have the extension, the relay uses the one whose helper started last. To pick another, add `--socket` and one of the sockets in `/tmp/claude-mcp-browser-bridge-<you>/` to the server's command.
- The copy whose account the extension is signed in to has both Anthropic's own Claude in Chrome tools and these. Either works.
- It leaves out picking between browsers, uploading files or images from the chat, GIF recording and shortcuts.
- Only Code sessions are tested. A copy's chat could use it from that copy's `claude_desktop_config.json`, with `--label` to name its tab group.
- To add it by hand, or to another MCP client: `claude mcp add --scope user chrome-relay -- ~/claude-multi-account/apps/notch/build/claude-chrome-relay`. Remove it with `claude mcp remove --scope user chrome-relay`.

> **Note:** Anthropic doesn't support this. It relies on how the extension and its helper work today: the extension already refuses these local commands when a company manages it, and an update could do the same for everyone. Any copy that has the relay can drive your Chrome profile, signed-in sites included, so turn access off when you don't want that.
