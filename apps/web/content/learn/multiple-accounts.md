---
title: Running more than one Claude account on a Mac
description: Signing out and in, browser profiles, separate copies of the desktop app, and Claude Code config folders, with what each one costs you.
summary: Personal, work and client accounts side by side, and the trade-offs.
order: 4
checked: "2026-10-19"
sources:
  - title: Log in to your Claude account (Claude Help Center)
    url: https://support.claude.com/en/articles/13189465-log-in-to-your-claude-account
  - title: Find and join a Team or Enterprise organization (Claude Help Center)
    url: https://support.claude.com/en/articles/13566435-find-and-join-a-team-or-enterprise-organization
  - title: Purchase and manage seats on Team plans (Claude Help Center)
    url: https://support.claude.com/en/articles/12004354-purchase-and-manage-seats-on-team-plans
  - title: Consumer Terms of Service (Anthropic)
    url: https://www.anthropic.com/legal/consumer-terms
  - title: Authentication (Claude Code docs)
    url: https://code.claude.com/docs/en/authentication
  - title: Environment variables (Claude Code docs)
    url: https://code.claude.com/docs/en/env-vars
  - title: Commands (Claude Code docs)
    url: https://code.claude.com/docs/en/commands
  - title: "Feature request: several Claude accounts in the desktop app (anthropics/claude-code#18435)"
    url: https://github.com/anthropics/claude-code/issues/18435
---

Plenty of people have more than one Claude account: a personal plan and a work Team, say, or an account for each client. Claude's apps are built around one account at a time, so keeping several to hand takes a little setting up.

## What Claude supports

- **Personal and work on one email.** The account menu switches between a personal account and a Team or Enterprise account on the same email address. Each keeps its own conversations and projects.
- **Several organizations.** One person can belong to several Team or Enterprise organizations.
- **Different emails:** we found no official way to stay signed in to accounts with different email addresses at once. It's a popular request: [anthropics/claude-code#18435](https://github.com/anthropics/claude-code/issues/18435) has been open since January.

Before you start: Anthropic's terms say not to share your login or let anyone else use your account, and each Team seat belongs to one named person. Everything here is about running your own accounts.

## Your options

### Sign out and back in

Works everywhere and costs nothing. But it's slow, it's easy to start a chat in the wrong account, and in Claude Code `/logout` removes every stored login, MCP server logins included.

### A browser profile per account

Each Chrome, Edge, Firefox or Safari profile keeps its own sign-in, so claude.ai can be open in two accounts side by side. You give up the desktop app.

### Separate copies of the desktop app

Claude's desktop app is built on Electron, which keeps one account's data in one folder. Started with a different data folder, the same app runs as a separate copy with its own login. Claude Notch's installer sets this up with a launcher per copy, and every copy runs the one Claude.app in your Applications folder, so they all update together.

Three things go wrong without help:

1. Opening Claude the usual way can start a second copy on a folder that's already open, which can corrupt it.
2. The sign-in link from your browser goes to whichever copy started first, not the one you're signing in.
3. The copies look the same.

Claude Notch handles all three: launchers that bring an open copy to the front, sign-in links sent to the copy you used last, and an outline and a hotkey for each copy. [How it works](/docs/how-it-works) has the details. Each copy is a whole app, so expect 0.5 to 1 GB of memory for each one that's open.

### Claude Code in the terminal

Claude Code supports this itself. Set `CLAUDE_CONFIG_DIR` to a different folder for each account, and each keeps its own settings, history and claude.ai login:

```bash
alias claude-work='CLAUDE_CONFIG_DIR=~/.claude-work claude'
```

Run `claude-work` and sign in with `/login`. On a Mac, each folder's login is kept in the Keychain separately. Anthropic Console logins without an API key aren't kept apart this way. [Claude Code and your limits](/learn/claude-code) has more, and with Claude Notch installed, `install.sh --claude-code` makes `claude-a`, `claude-b`… for you: [Claude Code in the terminal](/docs/claude-code).

## Which to pick

| | Stays signed in | Side by side | Desktop app | Seeing usage |
| --- | --- | --- | --- | --- |
| Sign out and in | No | No | Yes | Settings → Usage, one account at a time |
| Browser profiles | Yes | Yes | No | Settings → Usage in each profile |
| Desktop copies with Claude Notch | Yes | Yes | Yes | Every account in the notch |
| `CLAUDE_CONFIG_DIR` | Yes | Yes, one per terminal | No | `/usage` in each |

They mix, too: desktop copies for chat and a config folder per account for Claude Code.
