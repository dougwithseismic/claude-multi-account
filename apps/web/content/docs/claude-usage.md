---
title: claude-usage
description: Every account's limits in the terminal, with JSON output for scripts.
section: Using it
order: 7
---

`claude-usage` prints the same numbers as the panel. `install.sh` builds it into the repository:

```bash
~/claude-multi-account/apps/notch/build/claude-usage
```

Its first run asks for Keychain access too, like the app did; choose **Always Allow**.

## Options

| Option | Does |
| --- | --- |
| `--json` | Machine-readable output: one object per copy and organization, with each window's percent and reset time |
| `--only B,C` | Only those copies |
| `--verbose` | Also says, on stderr, where each copy's organization in use was read from |
| `--signed-in` | Lists the copies that have a login, without the Keychain or the network |

It exits 0 when at least one account's usage was read, 1 when none was, and 2 on bad arguments, so scripts can test it.

## Examples

Each copy's 5-hour use, one per line, with [jq](https://jqlang.org):

```bash
~/claude-multi-account/apps/notch/build/claude-usage --json | jq -r '.[] | select(.active) | "\(.letter) \(.usage.windows[]? | select(.label == "5-hour") | .percentUsed)"'
```

Only B's numbers:

```bash
~/claude-multi-account/apps/notch/build/claude-usage --only B
```
