# PRD 06: One-line install and `--doctor`

Status: shipped 2026-10-19.

## Goal

Installing takes two commands today and assumes git and Apple's command line tools. When something goes wrong, the only help is the README. A single pasted line should get anyone from nothing to a working Notch, and one command should say what's wrong and how to fix it.

## Locked decisions

- `https://dougwithseismic.github.io/claude-multi-account/install.sh` serves `bootstrap.sh` from the repo root (copied into the site at build). It checks macOS 26, Claude.app and the command line tools (and if they're missing, starts `xcode-select --install` and says to run the line again once it's done), then clones the repo into `~/claude-multi-account` (or pulls if it's there and clean), and runs `install.sh` with any arguments it was given. It takes no input. It prints each step like `install.sh` does.
- The site shows both: the one line, and the two commands for people who'd rather read the script first, with a link to it.
- `./install.sh --doctor` changes nothing. It checks, with a tick or a cross and a one-line fix for each: macOS version, Claude.app, Swift, profiles.json valid, each data folder, each launcher, Claude Notch installed and running, open at login, who gets `claude://` links, which copies are signed in, the Keychain item exists (without reading it), the snapshot's age, `claude-usage` on the PATH, and Claude.app copies running on the same folder twice.
- The docs' Troubleshooting page starts with `--doctor`.

## Acceptance criteria

- WHEN someone pastes `curl -fsSL …/install.sh | zsh` on a Mac with the tools the system SHALL end in the same state as the two-command install.
- WHEN the command line tools are missing the system SHALL start their installer and stop with "run this line again when it's done".
- WHEN `~/claude-multi-account` has local changes the system SHALL not pull over them, and say so.
- WHEN `./install.sh --doctor` runs the system SHALL change nothing and exit 0 when every check passes, 1 otherwise.

## Implementation notes

Shipped 2026-10-19.

- `bootstrap.sh` at the root; `apps/web/plugins/root-files.ts` serves it at `/install.sh` in dev and copies it into the build, so there's one file. The Pages workflow also runs when it changes. Everything is inside `main`, called on the last line, so a cut-short download runs nothing.
- A folder at `~/claude-multi-account` counts as ours if it's a git checkout with an executable `install.sh`, so forks and SSH clones work. With local changes it installs from them as they are, and says so, rather than stopping.
- `--doctor` is `scripts/doctor.sh`, which `install.sh` hands over to. Three marks: ✓, ✗ (counts toward exit 1) and – for choices that are the user's (not opening at login, `claude-usage` not on the PATH). It reads profiles.json the way the app does (an entry without a capital letter is skipped, a bad colour is grey) and reports each case.
- Opening at login comes from the app itself: `ClaudeNotch --login-item` prints `SMAppService.mainApp.status` and quits. The doctor only asks builds from 0.5 on, since older ones would start instead. The usage snapshot's age is checked from 0.5 on too (PRD 05 writes it).
- Tested: on this Mac (exit 0); against an empty home with a broken profiles.json (each problem listed, exit 1); bootstrap piped into zsh for a fresh clone, an update, local changes, a folder that isn't a checkout, and missing Command Line Tools (stubbed).
- Open: run the one line on a clean Mac once it's live.
