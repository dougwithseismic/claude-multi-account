---
title: Claude Code and your limits
description: How Claude Code shares your plan's limits, the /usage command, a status line that shows them, and a separate login per folder with CLAUDE_CONFIG_DIR.
summary: /usage, the status line's rate_limits, and one login per folder.
order: 6
checked: "2026-10-19"
sources:
  - title: How do usage and length limits work? (Claude Help Center)
    url: https://support.claude.com/en/articles/11647753-how-do-usage-and-length-limits-work
  - title: Use Claude Code with your Pro or Max plan (Claude Help Center)
    url: https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan
  - title: Models, usage, and limits in Claude Code (Claude Help Center)
    url: https://support.claude.com/en/articles/14552983-models-usage-and-limits-in-claude-code
  - title: Commands (Claude Code docs)
    url: https://code.claude.com/docs/en/commands
  - title: Manage costs effectively (Claude Code docs)
    url: https://code.claude.com/docs/en/costs
  - title: Customize your status line (Claude Code docs)
    url: https://code.claude.com/docs/en/statusline
  - title: Environment variables (Claude Code docs)
    url: https://code.claude.com/docs/en/env-vars
  - title: Authentication (Claude Code docs)
    url: https://code.claude.com/docs/en/authentication
  - title: Claude Code Wrap-Up Allowance (Claude Help Center)
    url: https://support.claude.com/en/articles/17040437-claude-code-wrap-up-allowance
  - title: Higher usage limits and a SpaceX compute deal (Anthropic, 6 May 2026)
    url: https://www.anthropic.com/news/higher-limits-spacex
  - title: "Desktop's Claude Code overwrites the CLI's login (anthropics/claude-code#101990)"
    url: https://github.com/anthropics/claude-code/issues/101990
---

Signed in with a Claude plan, Claude Code draws on the same limits as Claude's apps. Time in the terminal and chats in the app come out of one pool.

## See your limits

- `/usage`, also `/cost` and `/stats`, shows your plan's limit bars, the session's cost and recent activity. If the usage check is rate limited, it shows the last bars from the past hour.
- `/status` shows which account and model you're using.
- `/usage-credits` and `/rate-limit-options` cover what you can do at a limit.

## Put them in the status line

Claude Code's status line runs a command of yours and shows what it prints. The JSON it passes the command includes your plan's limits:

| Field | What it is |
| --- | --- |
| `rate_limits.five_hour.used_percentage` | The 5-hour window, 0 to 100 |
| `rate_limits.five_hour.resets_at` | When it resets, in Unix seconds |
| `rate_limits.seven_day.used_percentage` | The weekly window, 0 to 100 |
| `rate_limits.seven_day.resets_at` | When it resets, in Unix seconds |

They're there for Pro and Max subscribers, after the session's first response, and either can be missing. A script that shows both, using [jq](https://jqlang.org):

```bash
#!/bin/bash
# ~/.claude/statusline.sh: the model, then the 5-hour and weekly limits.
input=$(cat)
model=$(jq -r '.model.display_name // empty' <<<"$input")
five=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
week=$(jq -r '.rate_limits.seven_day.used_percentage // empty' <<<"$input")
line="$model"
[ -n "$five" ] && line="$line · 5h ${five%.*}%"
[ -n "$week" ] && line="$line · 7d ${week%.*}%"
echo "$line"
```

Make it runnable with `chmod +x ~/.claude/statusline.sh`, then add it to `~/.claude/settings.json`:

```json
{
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
}
```

The status line runs again after each message, uses no tokens, and only shows when the script exits with status 0.

## One login per folder

`CLAUDE_CONFIG_DIR` points Claude Code at a folder other than `~/.claude`. Each folder keeps its own settings, history and claude.ai login, and Anthropic's docs suggest it for running several accounts side by side:

```bash
alias claude-work='CLAUDE_CONFIG_DIR=~/.claude-work claude'
```

Set it in your shell, not in a project's settings, where Claude Code ignores it. With Claude Notch, `install.sh --claude-code` makes one command like this per copy, `claude-a`, `claude-b` and so on, with your settings and skills shared: [Claude Code in the terminal](/docs/claude-code).

> **Note:** One report says the Claude Code inside the desktop app can overwrite the terminal Claude Code's login in the Keychain ([anthropics/claude-code#101990](https://github.com/anthropics/claude-code/issues/101990)). If your terminal login keeps changing account, that may be why.

## What uses more

In Claude Code, Opus uses meaningfully more of your limits than other models, and higher effort uses more. Since 6 May 2026, Claude Code's 5-hour limits are double what they were on Pro, Max, Team and seat-based Enterprise plans. A small Wrap-Up Allowance lets a response that's already running finish when you reach the 5-hour limit.

## Every account at once

`/usage` shows the account Claude Code is signed in to. [claude-usage](/docs/claude-usage), which comes with Claude Notch, prints every desktop copy's limits in the terminal, with `--json` for scripts. And `install.sh --statusline` puts them all in Claude Code's status line, after the session's own: [Claude Code's status line](/docs/status-line).
