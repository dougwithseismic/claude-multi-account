# PRD 10: 1.0, Claude in Chrome for every copy and a sturdier install

Status: built 2026-11-01 on `release-1.0`, waiting on the user to merge and tag.

## Goal

`claude-chrome-relay` (PRs #5 and #6) worked, but only for someone who added it to Claude Code by hand, and a session whose tab group was closed was stuck until restarted. The app and installer had rough edges that show up over weeks of use: a copy made while the app ran didn't appear, numbers from before a sleep looked current, a second `./install.sh` could run over the first, and uninstall could leave a status line pointing at a deleted command. 1.0 makes the relay an installer feature and fixes those, and the GitHub README becomes a front page rather than a manual.

## Locked decisions

- **The version** lives in one place, `apps/notch/Sources/UsageCore/Version.swift`: the app's Info.plist (through `build-app.sh`), `claude-usage --version`, `claude-chrome-relay --version` and the doctor all read it. 1.0 is build 6.
- **The relay is opt in:** `./install.sh --chrome` adds it as a user-wide MCP server called `chrome-relay`, to `~/.claude` and to each `claude-b`… folder. A plain `./install.sh` keeps it current only once it's there. A `chrome-relay` pointing at another checkout's relay is moved; a different server with that name is left alone.
- **A lost tab group** (last tab closed, Chrome restarted) gets a new one on the next call that doesn't name a tab, and the call is repeated once. A call that names a tab fails as before, since repeating it in a new group would act on the wrong page.
- **`claude-chrome-relay --check`** says whether Chrome's helper is running and whether access is on; the doctor runs the same checks per folder. The relay logs what failed under the category `chrome-relay`.
- **The installer needs Swift 6.2** and says how to get it; one `./install.sh` at a time (a lock in `$TMPDIR`); a `Claude B.app` that isn't ours is left alone; process checks are per user, for fast user switching; a certificate that can't sign falls back to ad hoc rather than stopping.
- **Uninstall** removes the status line only through the command it points at, and says how to remove it by hand when that command is already gone; profiles.json goes last, since everything before it reads the letters from it.
- **No prebuilt download** until there's a Developer ID (backlog, "Needs the user").

## Acceptance criteria

- WHEN `./install.sh --chrome` runs the system SHALL add `chrome-relay` to `~/.claude.json` and to each `~/.claude-X` from `--claude-code`, and running it again SHALL change nothing.
- WHEN a session's tab group is gone the system SHALL make a new group on the next call without a tab id, and answer that call.
- WHEN a second `./install.sh` starts while one runs the system SHALL stop it with "another ./install.sh is running".
- WHEN Swift is older than 6.2 the system SHALL stop before building and say how to update.
- WHEN a copy is first started while Claude Notch runs the system SHALL show its ring within seconds, and remove a ring whose folder is deleted.
- WHEN a read fails because the network isn't back after a sleep the system SHALL try again 30 seconds later, backing off to the usual interval.
- WHEN numbers are older than 15 minutes the system SHALL dim them with their age and leave them out of the projection.
- WHEN macOS blocks passing a `claude://` link to a copy the system SHALL say so in a peek and open Privacy & Security → Automation, at most once a minute.
- WHEN profiles.json doesn't parse and Reload is clicked the system SHALL keep the profiles in use and say why under the row.
- WHEN the Keychain key changes while the app runs the system SHALL read it again once rather than fail every read until restarted.

## Implementation notes

- Committed as three changes: the relay (recovery, `--check`, `--version`, log, with `RecoveryTests`), the scripts (`--chrome`, doctor, uninstall, lock, Swift check, per-user process checks, signing fallback) and the app fixes. 223 tests pass.
- Scripts tested in a stand-in home with a fake `claude`: uninstall order, uninstall with the status line's command already gone, and a second install while the first held the lock. The doctor on the author's Mac reports Swift 6.2 and, as expected until reinstalling, Claude Notch 0.4 and launchers out of date.
- The stuck group was reproduced with the installed (pre-1.0) relay from a real Code session: closing the group's last tab gave "No tab available" on every later call. The fix is covered by `RecoveryTests` against a stand-in helper; the 1.0 relay hasn't run from a real session yet, since that needs a reinstall and a new session.
- `--chrome` was tested in a stand-in home: added, run again with no change, an older checkout's relay moved, and another server named `chrome-relay` left alone.
- The blocked-link peek is checked in the demo snapshot only; nobody has seen macOS block a link since 0.4.
- Docs: `/docs/chrome` is new; install, sign-in, day to day, settings, how it works, privacy, Claude Code, updating and troubleshooting cover 1.0; the home page's walkthrough, grid and platforms mention Claude in Chrome, and its badge reads "New in 1.0: Claude in Chrome for every copy". `README.md` opens with what it is, the poster, the install line and what you get, and keeps the reference below.
- Not done: tagging `v1.0` and a GitHub Release, the repo's About text and topics, and installing 1.0 on the author's Mac, all waiting on the user.
