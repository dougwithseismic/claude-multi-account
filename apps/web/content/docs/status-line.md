---
title: Claude Code's status line
description: Every copy's 5-hour and weekly use under Claude Code's prompt, from what Claude Notch read last. One command adds it.
section: Using it
order: 8
---

Claude Code's status line is the line under its prompt. One command puts every copy's usage there:

```bash
~/claude-multi-account/install.sh --statusline
```

## Reading it

```text
Code 41·63  ▸A 37·62  B 92·✕  C 12·30
```

- Each copy shows its **letter** in its colour, then its **5-hour** and fullest **weekly** window, in percent.
- A figure turns **red** from 90%, and **✕** means that window is used up.
- **▸** marks the copy in front. A copy whose numbers are old is dimmed.
- **Code** leads with the session's own limits, when Claude Code passes them: on Pro and Max plans, after the session's first answer.
- In a narrow window, the copies on the right go first.

It comes from the file Claude Notch writes after each read, so it costs no tokens, makes no network call and never asks for the Keychain. It answers in under 20 ms. If Claude Notch isn't running, or hasn't read for 15 minutes, the line says so in grey.

## What it changes

It adds this to `~/.claude/settings.json`, or `$CLAUDE_CONFIG_DIR/settings.json`, and leaves the rest of the file as it was:

```json
"statusLine": {
  "type": "command",
  "command": "/Users/you/.local/bin/claude-usage --statusline",
  "refreshInterval": 60
}
```

- The command is the `~/.local/bin` link to [claude-usage](/docs/claude-usage), or the repository's `apps/notch/build/claude-usage` without one.
- `refreshInterval` runs it once a minute while a session is idle, since Claude Notch's numbers change on their own.
- Add `--only A,B` to the command to show fewer copies.
- `install.sh --uninstall` takes it out again, but only if it's this one.

## If you have a status line already

`install.sh` never replaces one. It prints the one you have and the setting to use, and leaves the file alone. To keep yours and add every copy after it, pass Claude Code's input on to `claude-usage` from your script:

```bash
#!/bin/bash
# ~/.claude/statusline.sh: your own line, then every copy's usage.
input=$(cat)
mine=$(jq -r '.model.display_name // empty' <<<"$input")
notch=$(~/.local/bin/claude-usage --statusline <<<"$input")
echo "$mine  $notch"
```

Swap the `mine=` line for what your script printed before. [Claude Code and your limits](/learn/claude-code) covers the fields Claude Code passes.
