---
title: claude-usage
description: Every account's limits in the terminal, the copy with the most room for scripts, and JSON output.
section: Using it
order: 7
---

`claude-usage` prints the same numbers as the panel. `install.sh` builds it into the repository, and links it into `~/.local/bin` when you have that folder, so with `~/.local/bin` on your PATH it's just `claude-usage`:

```bash
~/claude-multi-account/apps/notch/build/claude-usage
```

## Read live

On its own it reads every copy now, with each one's login, so its first run asks for Keychain access too, like the app did; choose **Always Allow**.

| Option | Does |
| --- | --- |
| `--json` | Machine-readable output: one object per copy and organization, with each window's percent and reset time |
| `--only B,C` | Only those copies |
| `--verbose` | Also says, on stderr, where each copy's organization in use was read from |
| `--signed-in` | Lists the copies that have a login, without the Keychain or the network |

## From Claude Notch's last read

These read the file Claude Notch writes after each read, so they never touch the Keychain or the network and answer at once.

| Option | Does |
| --- | --- |
| `--cached` | The same rows, for the organization each copy is working in. `--json` and `--only` work too. With no file, or none from the last 15 minutes, it says so and exits 1 |
| `--best` | The letter of the copy with the most room, as <kbd>⌥⌘0</kbd> picks it. Exits 1 when no copy has room. Without a recent read from Claude Notch, it reads live |
| `--statusline` | One line for [Claude Code's status line](/docs/status-line) |

`CLAUDE_NOTCH_SNAPSHOT=<file>` points them at another file instead of `~/Library/Caches/claude-multi-account/usage.json`, to try them with made-up numbers.

It exits 0 when at least one account's usage was read, 1 when none was, and 2 on bad arguments, so scripts can test it.

## Examples

Open the copy with the most room:

```bash
letter=$(claude-usage --best) && open ~/Applications/"Claude $letter.app"
```

Each copy's 5-hour use, one per line, with [jq](https://jqlang.org):

```bash
claude-usage --json | jq -r '.[] | select(.active) | "\(.letter) \(.usage.windows[]? | select(.label == "5-hour") | .percentUsed)"'
```

Only B's numbers, from the last read:

```bash
claude-usage --cached --only B
```
