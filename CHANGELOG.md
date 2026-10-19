# Changelog

What changed for people who use Claude Notch, newest first. To update, `git pull` and run `./install.sh` again.

## Unreleased

### Site

- Docs: install, sign in, reading the panel, settings, `claude-usage`, troubleshooting and more, on the site instead of the README.

## 2026-10-18 · installer and site

### Install

- One script, `install.sh`, sets everything up: data folders, profiles.json, the Claude A, B and C launchers, and Claude Notch. It takes no input and is safe to run again. `./install.sh 4` adds a copy; `./install.sh --uninstall` takes it all out and keeps each copy's login.
- `claude-usage --signed-in` lists the copies that have a login, without the Keychain or the network.

### Site

- The marketing page, with a film and a hero loop recorded from the real app, published on GitHub Pages.

## 0.4 — 2026-10-17

### App

- The panel grows out of the notch as one shape and folds back into it.
- Private by default: rows show the profile's name and plan; the eye, or holding ⌥, shows emails and Team names.
- Peeks under the notch after a ⌥⌘ switch, and when the copy in use passes 90% of its 5-hour limit, runs out, or gets a limit back.
- A settings page behind the gear: details, open on hover or click, alerts, peeks, haptics, open at login, and profiles.json.
- A pace tick on each bar.
- With every copy out, the closed notch counts down to the first one back. Hover a reset time to see it as a clock time.

## Before 0.4 — 2026-10-15 to 17

### App

- Every organization a login belongs to is shown, so a Team beside a personal plan is handled, with the one in use first.
- Hotkeys (⌥⌘1, 2, 3), the window outline and `claude://` link routing moved into the app, replacing Hammerspoon and the separate link router.
- Works on screens without a notch, starts at login, and reads names, colours and keys from profiles.json.

### Command line

- `claude-usage` prints every account's 5-hour, weekly and per-model limits in the terminal, with `--json` and `--only`.
- Claude Notch shows a double ring per account beside the notch, and a panel with every limit on hover.

### Guide

- The guide and scripts for running two, then three or more, Claude desktop accounts side by side, each with its own data folder and launcher.
