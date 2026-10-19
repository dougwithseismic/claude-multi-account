---
title: Claude Code in the terminal
description: claude-a, claude-b and claude-c run Claude Code with each copy's own login, so the terminal can use whichever account has room.
section: Using it
order: 9
---

The desktop copies each keep their own login, but Claude Code in the terminal has one, in `~/.claude`. One command gives it one per copy:

```bash
~/claude-multi-account/install.sh --claude-code
```

It puts a command for each copy in profiles.json into `~/.local/bin`:

| Command | Claude Code with | Its folder |
| --- | --- | --- |
| `claude-a` | The login you have now | `~/.claude` |
| `claude-b` | Claude B's login | `~/.claude-B` |
| `claude-c` | Claude C's login | `~/.claude-C` |

Run `claude-b` once and sign in when Claude Code asks, then the same for `claude-c`. After that each stays signed in, like its desktop copy. They take everything `claude` does: `claude-b --resume`, `claude-c -p "…"`, `claude-b auth status`.

Sign each one in to the same account as the desktop copy with its letter. Limits belong to the account, so Claude B's ring then counts what `claude-b` uses too.

## What they share

Each command starts Claude Code with `CLAUDE_CONFIG_DIR` set to its folder, where Claude Code keeps everything: settings, login, history and plugins. So that every login has the same setup, `~/.claude-B` links to these in `~/.claude`:

- `settings.json` and `CLAUDE.md`
- `skills`, `agents`, `commands` and `plugins`

Its login, history and projects are its own. One of these that's already in the folder stays as it is and is never replaced, and you can remove a link to give that copy something different.

MCP servers you add for yourself are kept beside the login, so add them to each one: `claude-b mcp add …`.

## The one with the most room

[`claude-usage --best`](/docs/claude-usage) prints the letter of the copy with the most room. Put this in `~/.zshrc` to start Claude Code on it:

```bash
# Claude Code on the copy with the most room.
claude-best() { local letter; letter=$(claude-usage --best) && "claude-${(L)letter}" "$@" }
```

With [the status line](/docs/status-line) set, a `claude-b` session's own limits come first, as **Code B** in B's colour, then every copy's.

## Adding a copy, and taking them out

- `./install.sh --claude-code` again makes the command for a copy you've added to profiles.json. Once you have them, every `./install.sh` updates them.
- It only ever changes the commands it made. A `claude-b` of your own in `~/.local/bin` is left alone.
- `./install.sh --uninstall` removes the commands. It leaves the folders, with their logins and history, and prints the line to delete them. To sign one out first: `claude-b auth logout`.
- [`--doctor`](/docs/troubleshooting#check-the-setup) checks each command's folder and links.

`~/.local/bin` needs to be on your PATH to type just `claude-b`. Claude Code needs to be installed already: [Claude Code's setup](https://code.claude.com/docs/en/setup).
