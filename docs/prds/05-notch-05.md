# PRD 05: Notch 0.5, pace, best account, status line and first run

Status: not started.

## Goal

The Notch shows how much of each limit is used. It doesn't yet say what that means for the next hour, which copy to switch to, or how to read it the first time. And people who live in Claude Code in a terminal can't see any of it there. This release adds the answers, inside the app and in the terminal, without one more network call.

## Locked decisions

- **No new network calls.** Everything here is worked out from the numbers the app already reads every 5 minutes.
- **Shared snapshot.** After every read, the app writes `~/Library/Caches/claude-multi-account/usage.json` (folder 0700, file 0600, written atomically). It holds only what's needed to draw a ring: per copy its letter, label from profiles.json, plan name, whether it's the one in front, its state (`ok`, `stale`, `rateLimited`, `signedOut`, `keychain`, `unavailable`, `noLimits`), the time of the last good read, and each window's label, percent and reset time, for the organization in use only. Never tokens, emails, organization names or UUIDs. The schema has a `version: 1` field. Writing it can't make the app fail: errors are logged and ignored. `--demo` and the film never write it.
- **`claude-usage` reads it** with `--cached` (no Keychain, no network, never a prompt). With no file, or one older than 15 minutes, it says so and exits 1.
- **Status line.** `claude-usage --statusline` prints one line for Claude Code's `statusLine` setting, from the snapshot only, so it's instant and never prompts. It reads and ignores the JSON Claude Code sends on stdin (don't block if stdin is a terminal or empty). One segment per copy: the letter in its colour, then 5-hour and weekly peak percentages, for example `A 37·62  B 92·✕  C 12·30`, with red at 90% and `✕` for a full weekly limit, and the copy in front marked. `--only` filters. If the snapshot is missing or stale it prints a short dim hint, never an error. ANSI colour always (the status line renders it). Follow the official status line docs for the stdin and output rules.
- **Pace projection.** For a window with a reset time, using the same elapsed share the pace tick uses: once at least 10% of the window has passed and at least 5% is used, if the current rate would reach 100% before the reset, the row's reset text becomes "out ~15:40 at this pace" in the alert orange. Otherwise nothing changes. Pure function in UsageCore with tests. The 5-hour window is 5 hours and the weekly ones 7 days.
- **Best account.** The copy with the most room: among copies whose organization in use read fine in the last 15 minutes and isn't out of any window, the one whose fullest window (5-hour or weekly peak) is lowest; ties go to the profile order. Pure function in UsageCore with tests.
  - **⌥⌘0** switches to it, with the usual switch peek. If 0 is a profile's own hotkey, that wins and ⌥⌘0 does nothing.
  - The panel's footer adds "Most room: Claude C" when there's more than one copy.
  - `claude-usage --best` prints the best copy's letter from the snapshot (or from a live read with no snapshot), exit 1 if none has room. Useful in scripts.
  - A settings switch, "⌥⌘0 switches to the most room", on by default.
- **First run.** The first time the app opens with no `welcomeSeen` default, the panel opens on a welcome page (it doesn't wait for a hover): "How to read it" with the ring and bar legend the settings page already has, then a checklist built from what the app knows: Keychain allowed, each copy signed in or not (a "Sign in" button on each that isn't, which opens that copy as clicking its row does), and the hotkeys. "Got it" sets `welcomeSeen` and folds the panel. Settings gets "Show the welcome page again". The welcome page is reachable in `--demo` with `--welcome`.
- **Learn more.** The settings page gets two links that open in the browser: "How limits work" (`https://dougwithseismic.github.io/claude-multi-account/learn/how-limits-work/`) and "What's new in 0.5" (`…/changelog/`).
- **install.sh:** links `claude-usage` into `~/.local/bin` when that folder exists (the uninstall removes the link if it points at ours). `./install.sh --statusline` adds Claude Code's `statusLine` to `~/.claude/settings.json` pointing at `claude-usage --statusline`, only when that file has no `statusLine` already (it never replaces one; it prints what's there and how to change it by hand). Keep the rest of `settings.json` exactly as it is.
- Version 0.5 (`CFBundleShortVersionString` 0.5, `CFBundleVersion` 5).

## Acceptance criteria

- WHEN the app finishes a read the system SHALL write the snapshot file with mode 0600 and no token, email or organization name in it.
- WHEN `claude-usage --cached` runs with a fresh snapshot the system SHALL print the same rows as a live read for the organizations in use, without touching the Keychain or the network.
- WHEN Claude Code runs `claude-usage --statusline` the system SHALL print one line within 50 ms, with each copy's letter, 5-hour and weekly percentages, colours and the copy in front marked.
- WHEN the snapshot is missing or older than 15 minutes the status line SHALL print a dim "Claude Notch isn't running" or "usage 20m old" hint and exit 0.
- WHEN a 5-hour window is 40% used 1 hour in the system SHALL show "out ~" with the time 2.5 hours from the start, because 40% an hour reaches 100% at 2h30m, before the 5-hour reset.
- WHEN a window is on or under an even pace the system SHALL show the reset text as before.
- WHEN ⌥⌘0 is pressed the system SHALL switch to the copy with the most room and peek its name.
- WHEN no copy has room the system SHALL peek "No copy has room" with the first reset, and not switch.
- WHEN the app opens for the first time the system SHALL show the welcome page with each copy's sign-in state, and not show it again after "Got it".
- WHEN `./install.sh --statusline` runs and `~/.claude/settings.json` already has a `statusLine` the system SHALL leave the file unchanged and say so.
- WHEN `swift test` runs the system SHALL cover the pace projection, best-account choice, snapshot encoding (no secrets), status line formatting and settings.json merge.

## Tasks

1. UsageCore: `PaceProjection`, `BestCopy`, `SharedSnapshot` (encode, decode, write, read, age) with tests.
2. App: write the snapshot after each read; projection in rows; best-account footer, ⌥⌘0 and setting; welcome page; settings links.
3. CLI: `--cached`, `--statusline`, `--best`, help text.
4. install.sh: `~/.local/bin` link, `--statusline`, uninstall.
5. README and the app's docs page updates; version bump.

## Implementation notes

(Filled in after shipping.)
