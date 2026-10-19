# Changelog

What changed for people who use Claude Notch, newest first. To update, `git pull` and run `./install.sh` again.

## Unreleased

### Site

- Docs: install, sign in, reading the panel, settings, profiles, `claude-usage`, troubleshooting, privacy, how it works and updating, on the site instead of the README.
- A pace calculator: enter how much of a 5-hour or weekly limit you've used and when it resets, and see whether it lasts, when you'd run out at the rate so far, and how much an hour you can use to make it last. Works for anyone, on any computer. Links keep the inputs, so a result can be shared.
- A setup planner: pick how many accounts, name them, give each a colour and hotkey, and get the rings as the Notch would draw them, the install command and the profiles.json.
- This changelog, on the site.
- Link previews for every page, a sitemap and robots.txt.

### Guides

- Seven guides to Claude's limits, each citing Anthropic's own pages and dated: how the 5-hour and weekly limits work, what each plan gets, pacing, several accounts on one Mac, Teams and organizations, limits in Claude Code, and reading the rings. Pacing and the rings guide have figures you can drag.

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
