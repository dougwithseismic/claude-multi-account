# PRD 09: Claude Code in the terminal, one login per copy

Status: shipped 2026-10-19, in 0.5.

## Goal

The desktop copies each have their own login, but Claude Code in the terminal has one, in `~/.claude`, so the terminal can't use whichever account has room. The compare page listed this under "where others are ahead". Claude Code now supports a folder per account itself (`CLAUDE_CONFIG_DIR`, in Anthropic's docs with a `claude-work` alias as the example), so the installer can set it up per copy with nothing new in the app.

## Locked decisions

- **`./install.sh --claude-code`** makes one command per profile in `~/.local/bin`: `claude-a`, `claude-b`, …, lower-case letter. It needs profiles.json and `~/.local/bin`, and fails with what to do if either is missing.
- **`claude-a` is Claude Code as it is now:** it unsets `CLAUDE_CONFIG_DIR` and runs `claude`, so it's always `~/.claude`.
- **`claude-b`** exports `CLAUDE_CONFIG_DIR="$HOME/.claude-B"` and runs `claude "$@"`. The folder is made 0700.
- **Shared setup:** `~/.claude-B` gets links to `~/.claude`'s `settings.json`, `CLAUDE.md`, `skills`, `agents`, `commands` and `plugins`, each only if `~/.claude` has it and the folder doesn't. Nothing in the folder is ever replaced. Logins, history, projects and `.claude.json` (where user MCP servers live) stay per folder.
- **Only ours:** every command carries a marker line. A `claude-x` without it is left alone, and only marked ones are rewritten or removed.
- **`./install.sh`** re-runs it when `claude-a` is ours, so new profiles get their command; otherwise it prints the one-line hint.
- **`--uninstall`** removes our commands, never the folders, and prints `rm -rf` for `~/.claude-[A-Z]`.
- **`--doctor`** gets a Claude Code section: `claude` on the PATH, each command's folder there, no links to things `~/.claude` no longer has, a command for a letter no longer in profiles.json. It never runs `claude` (that would read its Keychain item), so whether each is signed in is a hint to run `claude-b auth status`.
- **Status line:** in a session started by `claude-b`, the session's own segment reads "Code B" in B's colour. `claude-usage --statusline` takes the letter from `CLAUDE_CONFIG_DIR` when its last component is `.claude-X`.
- The app is unchanged: rings stay per desktop copy. Signing `claude-b` in to Claude B's account makes B's ring count both, since limits are per account.

## Acceptance criteria

- WHEN `./install.sh --claude-code` runs with profiles A to C the system SHALL write executable `claude-a`, `claude-b` and `claude-c` into `~/.local/bin`, make `~/.claude-B` and `~/.claude-C` with mode 0700, and link the shared items that `~/.claude` has.
- WHEN it runs again the system SHALL change no file, link or mode.
- WHEN `~/.local/bin/claude-d` exists and isn't ours the system SHALL leave it as it is and say so.
- WHEN `~/.claude-C/settings.json` is a file of its own the system SHALL keep it and link the rest.
- WHEN `claude-a` runs with `CLAUDE_CONFIG_DIR` set the system SHALL run Claude Code on `~/.claude`.
- WHEN `claude-b auth status` runs the system SHALL report `~/.claude-B` as the config folder, and not signed in until B signs in.
- WHEN `--uninstall` runs the system SHALL remove only our commands and print how to delete the folders.
- WHEN `--doctor` finds a folder linking to something `~/.claude` lost the system SHALL say which and how to fix it.
- WHEN Claude Code runs the status line with `CLAUDE_CONFIG_DIR=~/.claude-B` the system SHALL start the line "Code B" in B's colour.

## Implementation notes

- `install.sh` reads the letters from profiles.json with the same JXA as the rest of the script; the commands are `#!/bin/sh` and `exec claude "$@"`, so arguments pass through untouched.
- Tested in a stand-in home (fake `claude`, profiles A to D, a foreign `claude-d`, a `~/.claude-C` with its own settings.json): first run, re-run (no file, link or mode changed), each command's `CLAUDE_CONFIG_DIR`, `--uninstall` (removed a to c, kept d, printed the `rm -rf`), and `--doctor` with a link broken and mended.
- With the real Claude Code 2.1.280 on the author's Mac: `claude-b auth status` in the stand-in home said `loggedIn: false` with `configDirectory` `~/.claude-B`, and `claude-a auth status` with a stray `CLAUDE_CONFIG_DIR` said signed in, Max, on `~/.claude`. Claude Code writes `.claude.json` into the config folder, so user MCP servers are per folder.
- Not done: `--claude-code` hasn't been run in the author's real home, and nobody has signed a `claude-b` in yet. An empty folder's `.claude.json` already holds account fields after `auth status`, so the doctor can't tell signed in from that file, which is why it doesn't try.
- Docs: `/docs/claude-code` is new (Using it, order 9); troubleshooting, install, updating, status line, the Claude Code and several-accounts guides, the compare page, the README, the FAQ and the 0.5 changelog cover it.
