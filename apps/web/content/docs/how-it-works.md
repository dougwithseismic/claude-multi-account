---
title: How it works
description: Why each copy of Claude stays signed in on its own, and the two problems Claude Notch solves to make that work.
section: Help
order: 11
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

The full design, with the research behind each choice, is in the [app's design document](https://github.com/dougwithseismic/claude-multi-account/blob/main/docs/notch-prd.md).
