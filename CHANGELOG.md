# Changelog

What changed for people who use Claude Notch, newest first. To update, paste the install line again, or `git pull` and run `./install.sh`.

## 1.1 — 2026-11-03

- The rings sit left of the notch, so they no longer cover menu bar icons. **Rings** in settings puts them back on the right; the gear, eye and refresh buttons move to the other side of the open panel.
- **Copies** in settings: **Manage…** opens a window to add a copy in one click (its data folder, launcher, colour and ⌥⌘ key), rename it, change its colour or key, and remove it, keeping its login unless you choose to delete its data.
- profiles.json applies when it's saved, without Reload, and a letter added to it by hand gets its copy made.
- A new copy's ring shows as soon as it's made, dimmed with "Sign in to Claude D", instead of after its first start.
- `install.sh` and the Copies window make copies with the same script, `files/claude-copy.sh`.

## 1.0 — 2026-11-01

### Claude in Chrome for every copy

- `./install.sh --chrome` gives every copy's Code sessions the Claude in Chrome tools, through your usual Chrome profile. It adds `claude-chrome-relay` to Claude Code in `~/.claude`, which every desktop copy's Code tab reads, and in each `claude-b`… folder. Each session works in its own tab group, named after its copy. Once it's set up, a plain `./install.sh` keeps it up to date, and `--uninstall` takes it out again. [The guide](https://dougwithseismic.github.io/claude-multi-account/docs/chrome/) has the details.
- **Chrome access for every copy**, a switch in settings: off, the relay refuses every call and nothing reaches Chrome. While it's on, a globe beside a copy's name shows it used Chrome in the last minute.
- A session whose tab group went away (its last tab closed, or Chrome restarted) gets a new group on its next call, instead of "No tab available" until it's restarted.
- `claude-chrome-relay --check` says whether Chrome's helper is running and access is on, without connecting. What goes wrong is in the system log, without pages or anything typed.
- `./install.sh --doctor` says which folders have the relay, whether it's up to date, and whether Chrome's helper is running.

### App

- A copy opened for the first time shows up while Claude Notch runs, and a deleted one goes, without a restart.
- After a sleep, a read that fails because the network isn't back yet is tried again in 30 seconds, not 5 minutes. Until then, numbers older than 15 minutes are dimmed and say how old they are.
- While every account is waiting (on a rate limit, or the Keychain), the status line keeps showing each copy's last numbers, dimmed, instead of saying Claude Notch stopped.
- More copies than fit on the screen scroll. On a screen without a notch, the pill widens for more than six.
- If macOS won't let Claude Notch pass a sign-in link to a copy, a peek says so and Privacy & Security → Automation opens, where you can allow it. Before, the link was dropped with a beep.
- Reloading a profiles.json with a mistake in it keeps the names and colours in use and says what's wrong, instead of going back to A, B and C.
- If Claude makes a new Keychain key, Claude Notch reads it again instead of showing "Can't decrypt Claude's login" until it's restarted.
- Signing a copy in to another account in the same Team no longer hides that account for up to 12 hours.

### Install

- `install.sh` checks for Swift 6.2 up front, and says what to do when the Command Line Tools are there but Swift won't run (usually a licence to accept).
- Two `./install.sh` runs at once: the second stops and says so.
- An app of your own called `Claude B.app` in `~/Applications` is left alone.
- With fast user switching, another user's Claude no longer counts as yours: launchers, the doctor and the installer only look at your own.
- When the signing certificate can't be used (the login Keychain locked, say over SSH), the build signs ad hoc and says so instead of stopping.
- The install line carries on with what's in `~/claude-multi-account` when git can't fast-forward it (a branch of your own, say), instead of stopping.
- `--uninstall` takes the relay out and stops it before removing the Chrome switch, and says how to remove the status line by hand if `claude-usage` isn't built.
- `claude-usage --version` and `claude-chrome-relay --version`.

### Site

- A Claude in Chrome guide, and Chrome in the walkthrough, the features and the FAQ.
- The README is now the repository's front page: what it does, the install line, and links to the guides.

## 0.5 — 2026-10-19

### App

- **Pace:** when a window is going fast enough to run out before it resets, its row says when, in orange: "out ~15:40 at this pace". At an even pace or slower, nothing changes.
- **⌥⌘0** switches to the copy with the most room, and the panel's footer names it ("Most room: Claude C"). When every copy is out, a peek says so and which one is back first. A switch in settings turns it off.
- **A welcome page** on the first run: how to read the rings and bars, then a checklist of the Keychain, each copy's sign-in (with a button that opens a copy that isn't signed in) and the hotkeys. Settings can show it again, and link to the guides and this changelog.
- After each read the app keeps what it read in a file only you can read, for `claude-usage` and the status line. It never holds a login, an email or an organization's name.

### Command line

- One line installs everything: `curl -fsSL https://dougwithseismic.github.io/claude-multi-account/install.sh | zsh`. It checks the Mac, opens the Command Line Tools installer if they're missing, gets the code into `~/claude-multi-account` or updates it (never over changes of your own), and runs `install.sh`. Add `-s -- 4` for four copies.
- `./install.sh --doctor` checks the whole setup and changes nothing: macOS, Claude.app and Swift, profiles.json, each copy's folder, launcher and sign-in, a copy open twice, whether Claude Notch is up to date, running and opening at login, where sign-in links go, the Keychain item, how recently usage was read, and each `claude-a`, `claude-b`… command's folder. Each problem comes with how to fix it.
- `./install.sh --statusline` puts every copy's 5-hour and weekly use in Claude Code's status line, after the session's own: `Code 41·63  ▸A 37·62  B 92·✕  C 12·30`. It never replaces a status line you already have.
- `./install.sh --claude-code` makes `claude-a`, `claude-b`, `claude-c`: Claude Code in the terminal with each copy's own login, in `~/.claude-B` and so on, sharing your settings, `CLAUDE.md`, skills, agents, commands and plugins. Sign each in to the same account as its desktop copy and that copy's ring counts both. In a `claude-b` session the status line starts "Code B".
- `claude-usage --cached` prints the last read with no Keychain prompt and no network, and `--best` prints the letter of the copy with the most room, for scripts.
- `install.sh` links `claude-usage` into `~/.local/bin` when you have that folder. `--uninstall` takes the link, the status line and the `claude-a`, `claude-b`… commands out again, if they're ours.

### Site

- Docs: install, sign in, reading the panel, settings, profiles, `claude-usage`, the status line, Claude Code in the terminal, troubleshooting, privacy, how it works and updating, on the site instead of the README.
- A pace calculator: enter how much of a 5-hour or weekly limit you've used and when it resets, and see whether it lasts, when you'd run out at the rate so far, and how much an hour you can use to make it last. Works for anyone, on any computer. Links keep the inputs, so a result can be shared.
- A setup planner: pick how many accounts, name them, give each a colour and hotkey, and get the rings as the Notch would draw them, the install command and the profiles.json.
- This changelog, on the site.
- A compare page: the other usage trackers, side-by-side launchers and account switchers, what each does, where they're ahead, and when to pick one instead.
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
