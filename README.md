# Several Claude accounts side by side on a Mac

Run the Claude desktop app two or more times, each copy signed in to a different account, and always know which one you're in. It sets up three (A, B and C) unless you ask for more.

When you're done you have:

- **Claude A**: your normal Claude, using the usual data folder.
- **Claude B** and **Claude C**: extra copies, each with its own data folder (`Claude-B`, `Claude-C`), so each has its own login and settings.
- **Claude Notch**, a small app of ours that:
  - shows every account's 5-hour and weekly limits at the MacBook notch, and when one will run out at the pace it's going;
  - switches to A, B or C with **⌥⌘1 / ⌥⌘2 / ⌥⌘3**, starting it if it's closed, and to whichever has the most room with **⌥⌘0**;
  - draws an outline in that account's colour (blue, orange or green) round the window of whichever Claude is in front;
  - sends `claude://` links, including sign-in, to the Claude you used last instead of always to A.

Claude.app itself is never modified, so it stays signed and keeps updating as normal.

## Install

You need macOS 26 or later, the [Claude desktop app](https://claude.ai/download) in `/Applications`, and Apple's Command Line Tools (`xcode-select --install`) or Xcode. Paste this into Terminal:

```bash
curl -fsSL https://dougwithseismic.github.io/claude-multi-account/install.sh | zsh
```

It runs [`bootstrap.sh`](bootstrap.sh): it checks those three, clones this repository into `~/claude-multi-account` (or pulls, if it's there and unchanged), and runs `install.sh`. Or do that by hand:

```bash
git clone https://github.com/dougwithseismic/claude-multi-account.git ~/claude-multi-account
```

```bash
~/claude-multi-account/install.sh
```

Or point your coding agent at this repository and tell it to install it.

> **For AI agents:** run `./install.sh` from the repository root. It takes no input and is safe to run again. When it finishes, pass on the list it prints at the end: the Keychain prompt and signing in need the person at the keyboard.

`install.sh` does five things, and prints what it's doing:

1. **Data folders:** makes one for each extra copy, `~/Library/Application Support/Claude-B` and `Claude-C`. A new one starts with A's app preferences (`claude_desktop_config.json`, `developer_settings.json`) but never A's login.
2. **Profiles:** writes `~/.config/claude-multi-account/profiles.json`, each copy's name, colour and hotkey, if you don't have one yet.
3. **Launchers:** builds `Claude A.app`, `Claude B.app` and `Claude C.app` in `~/Applications`. Each brings its copy to the front if it's running and starts it if it isn't, so you can open them from Spotlight, Raycast or the Dock.
4. **Claude Notch:** builds it, installs it as `~/Applications/Claude Notch.app` and opens it. It has no Dock icon; quit it from its panel.
5. **`claude-usage`:** links the [command](#claude-usage) into `~/.local/bin` if you have that folder and nothing else there is called `claude-usage`.

To put every copy's usage in Claude Code's status line as well, run `./install.sh --statusline` (see [below](#claude-codes-status-line)). For Claude Code in the terminal with each copy's own login, run `./install.sh --claude-code` ([below](#claude-code-in-the-terminal)).

Run it again after a `git pull` to update. It keeps your profiles.json, settings and logins.

From now on, never open `/Applications/Claude.app` directly while a copy is running: it would start a second copy on A's folder. Use ⌥⌘1, ⌥⌘2 and ⌥⌘3, or the Claude A, B and C launchers.

### Allow Keychain access

Claude Notch's first run asks for access to "Claude Safe Storage". Enter your login password and click **Always Allow**. Each Claude copy encrypts its own login with that key, and the app reads the login to check usage.

The build is signed with your first code-signing certificate (or `CODESIGN_IDENTITY`), so later updates don't ask again. With no certificate it signs ad hoc, and every update asks again.

### Sign in to B and C

Do this once for each extra copy, one at a time:

1. Open it (⌥⌘2 for B, ⌥⌘3 for C). Its window gets that copy's outline.
2. Click sign in and finish in the browser.
3. When the browser asks to open Claude, allow it. The login goes to the copy you opened. The first time, macOS asks whether "Claude Notch" may control "Claude": click **Allow**.

Don't click into another Claude between steps 2 and 3, or that one becomes "last used" and receives the login. The notch panel's footer says which copy links go to.

Each copy stays signed in after that. Optional: give the copies different themes (Settings → Appearance), for example A in Light and B in Dark, so you can tell them apart at a glance.

Claude Notch adds itself to your login items on its first run (macOS shows a notification). Turn off **Open at login** in its settings (the gear at the top left of the panel) to stop that. Hotkeys, the outline and links need no Accessibility permission.

On its first run the panel opens by itself on a welcome page: how to read the rings and bars, and a checklist of what's left. It shows whether the Keychain allowed it, which copies are signed in (with a **Sign in** button that opens a copy, as clicking its row does), and the hotkeys. **Got it** folds it away for good. **Show the welcome page again** in its settings brings it back.

## Day to day

- **⌥⌘1**, **⌥⌘2** and **⌥⌘3** switch to A, B and C, and a peek under the notch names the one you switched to. So does clicking a row in the notch panel.
- **⌥⌘0** switches to the copy with the most room: of those read in the last 15 minutes and not out of any limit, the one whose fullest window (5-hour or weekly) is lowest. A tie goes to the earlier letter. When every copy is out, the peek says "No copy has room" and which copy is back first, and nothing switches. The panel's footer names the copy ("Most room: Claude C") when you have more than one. A profile whose own hotkey is `0` keeps it, and the switch in settings turns this off.
- Closing a Claude window doesn't quit that copy: it keeps running with no window, as Mac apps do. Switching handles this by sending it the same "reopen" message a Dock click sends, so a new window appears. To really quit a copy, press ⌘Q in it.
- The outline shows which Claude you're typing into. When another app is in front, the next `claude://` link goes to the Claude you used last ("Links go to Claude B" in the panel).
- **Claude in Chrome:** only the copies on the account the extension is signed in to can use it; see [Claude in Chrome in every copy](#claude-in-chrome-in-every-copy-experimental).
- **Built-in browser pane:** this is separate per copy, so each copy has its own site logins there.
- **Code tab:** the MCP servers and skills it uses live in `~/.claude`, which every copy shares. Transcripts and memory are shared too, which is useful, but don't run two accounts in the same git worktree at once.
- All copies write to the same log, `~/Library/Logs/Claude/main.log`.

## What Claude Notch shows

By default it stays collapsed: one double ring per Claude copy just right of the notch, in that copy's colour. The outer ring is the 5-hour window and the inner one the fullest weekly window. A red cross means that account is out for the week. A dot under a ring marks the copy in front. The rings never take clicks, so the menu bar icons under them still work. On a screen without a notch the rings sit in a small black pill at the top centre.

Rest the pointer on the notch, or click it, and the panel grows out of it with one row per copy: its name, plan, each window's bar and when it resets. The white tick on a bar marks how far through its window it is, so a bar past its tick is going faster than an even pace. Click a row to switch to that Claude. Move away and the panel folds back into the notch.

- **Pace:** when a window is going fast enough to run out before it resets, its row says when instead, in orange: "out ~15:40 at this pace". That's a straight line from what's used so far, so it waits until a tenth of the window has passed and 5% is used. At an even pace or slower, the row shows the reset as usual, and hovering the row always does.

- **Privacy:** rows show the profile's name ("Claude B") and plan, not the email or a Team's name, so the panel can open in front of anyone. The eye at the top left shows them; holding ⌥ over the panel shows them until you let go.
- **Peeks:** after a ⌥⌘ switch, a strip under the notch names the copy for a moment. When the copy in use passes 90% of its 5-hour limit, runs out of a limit, or gets one back, the strip says so for a few seconds. Peeks never take clicks and stay away while an app is full screen.
- **Settings** (the gear): show emails and team names, open on hover or only on click, limit alerts, switch peeks, ⌥⌘0, haptic feedback, Chrome access for `claude-chrome-relay`, open at login, and editing profiles.json. Under "Reading it": what the rings and bars mean, the welcome page again, and links to [how limits work](https://dougwithseismic.github.io/claude-multi-account/learn/how-limits-work/) and [what's new](https://dougwithseismic.github.io/claude-multi-account/changelog/).

**Teams and other organizations:** one login can belong to several organizations, for example a personal Max plan and a Team. Each has its own limits. The row shows the one that copy is working in (whichever you last picked in Claude's account menu), and any other organization below it, marked "not in use". Claude renews only the login of the organization it's working in. So if another one's numbers go stale, switch that Claude to it once to update them. An organization you've never used in that copy (a free personal plan, say) has no login and isn't shown.

It reads every account at launch and then every 5 minutes, and backs off when Anthropic rate-limits the check. It only reads: it never refreshes a login or changes Claude's files. Its only network calls are the usage and profile checks Claude Code's `/usage` makes.

After each read it shares what it read in `~/Library/Caches/claude-multi-account/usage.json`, for `claude-usage --cached`, `--best` and the status line. The file holds each copy's letter, name, colour, plan, whether it's in front, how its last read went and its windows' percentages and resets, for the organization each copy is working in. It never holds a login, an email, an organization's name or an ID, and only you can read it (mode 0600).

## Names, colours and keys

`~/.config/claude-multi-account/profiles.json` sets each copy's label, colour and hotkey. `install.sh` writes it from `files/profiles.json`:

```json
[
  { "letter": "A", "label": "Claude A", "color": "#2F7BF5", "hotkey": "1" },
  { "letter": "B", "label": "Claude B", "color": "#F5822F", "hotkey": "2" },
  { "letter": "C", "label": "Claude C", "color": "#2FB36B", "hotkey": "3" }
]
```

**Edit** under Profiles in Claude Notch's settings opens the file, and **Reload** applies your changes. `claude-usage` reads it too.

## Add more copies

To go from three to four (A to D):

```bash
~/claude-multi-account/install.sh 4
```

It adds D to profiles.json (purple, ⌥⌘4), makes its data folder and launcher, and restarts Claude Notch. Then open it with ⌥⌘4 and sign in as above. Its ring appears after its first start. Any number up to 26 works; copies after the ninth get no hotkey.

Each copy is a full Electron app, so expect roughly 0.5–1 GB of memory per open copy.

## `claude-usage`

The same numbers in the terminal. `install.sh` builds it into the repository at `apps/notch/build/claude-usage`, and links it into `~/.local/bin` when you have that folder:

```bash
~/claude-multi-account/apps/notch/build/claude-usage
```

On its own it reads every copy live, with each one's login, so its first run asks for Keychain access too. Add `--json` for machine-readable output, `--only B,C` to choose accounts, or `--verbose` to see where each copy's organization in use was read from. `--signed-in` only lists the copies that have a login, without the Keychain or the network; `install.sh` uses it.

These read what Claude Notch read last instead, so they never touch the Keychain or the network:

- `--cached` prints the same rows from Claude Notch's file (`--json` and `--only` work too). If there's no file, or Claude Notch hasn't read for 15 minutes, it says so and exits 1.
- `--best` prints the letter of the copy with the most room, as ⌥⌘0 picks it, for scripts: `letter=$(claude-usage --best) && open ~/Applications/"Claude $letter.app"`. It exits 1 when no copy has room. Without a recent read from Claude Notch it reads live.
- `--statusline` prints the one line for [Claude Code's status line](#claude-codes-status-line).

`CLAUDE_NOTCH_SNAPSHOT=<file>` points all three at another file instead of `~/Library/Caches/claude-multi-account/usage.json`, for tests or a made-up file.

## Claude Code's status line

```bash
~/claude-multi-account/install.sh --statusline
```

This adds every copy's usage to the line under Claude Code's prompt, from what Claude Notch read last:

```text
Code 41·63  ▸A 37·62  B 92·✕  C 12·30
```

Each copy shows its letter in its colour, then its 5-hour and fullest weekly window in percent. A figure turns red from 90%, and ✕ means that window is used up. ▸ marks the copy in front, and a copy whose numbers are old is dimmed. When Claude Code passes the session's own limits (Pro and Max plans, after the session's first answer), "Code" leads with them. In a narrow window the copies on the right go first. If Claude Notch isn't running, or hasn't read for 15 minutes, the line says so in grey.

It writes this to `~/.claude/settings.json` (or `$CLAUDE_CONFIG_DIR/settings.json`), leaving the rest of the file as it was:

```json
"statusLine": {
  "type": "command",
  "command": "/Users/you/.local/bin/claude-usage --statusline",
  "refreshInterval": 60
}
```

The command is the `~/.local/bin` link, or the repository's `apps/notch/build/claude-usage` without one. If you already have a status line, it's left alone: `install.sh` prints it and the setting to use instead, to change by hand. `refreshInterval` runs it once a minute even while a session is idle, as Claude Notch's numbers change on their own. Add `--only A,B` to the command to show fewer copies.

## Claude Code in the terminal

```bash
~/claude-multi-account/install.sh --claude-code
```

The desktop copies each keep their own login, but Claude Code in the terminal has one, in `~/.claude`. This makes a command per copy in `~/.local/bin`: `claude-a` is Claude Code as you have it now, on `~/.claude`, and `claude-b` runs Claude Code with `CLAUDE_CONFIG_DIR=~/.claude-B`, a folder of its own with its own login and history. Run `claude-b` once and sign in with the same account as Claude B, so B's ring counts both. They take everything `claude` does.

`~/.claude-B` links to `~/.claude`'s `settings.json`, `CLAUDE.md`, `skills`, `agents`, `commands` and `plugins`, so every login has the same setup; anything the folder already has stays as it is. With the status line set, a `claude-b` session's own limits read "Code B". It only changes commands it made, `./install.sh` updates them once they're there, and `--uninstall` removes them and leaves the folders, printing the line that deletes them.

## Claude in Chrome in every copy (experimental)

Claude in Chrome reaches Claude through Anthropic's servers, by account: the extension in a Chrome profile is signed in to one claude.ai account, and only copies on that account can use it. `claude-chrome-relay` works round that for the Code tab. It's an MCP server that sends the same browser tools to the extension through its helper on your Mac, which doesn't check the account. So every copy can work in your usual Chrome profile, with its logins, at the same time.

`install.sh` builds it into `apps/notch/build/claude-chrome-relay`. Add it once and every copy's Code tab gets it, since they share `~/.claude`:

```bash
claude mcp add --scope user chrome-relay -- ~/claude-multi-account/apps/notch/build/claude-chrome-relay
```

New Code sessions then have its tools (`mcp__chrome-relay__navigate` and the rest). Each session gets its own tab group in Chrome, named after its copy ("Claude B"), and sees only its own tabs.

**Chrome access for every copy** in Claude Notch's settings switches it on or off for all copies at once: off, the relay refuses every call and nothing reaches Chrome. The switch is the file `~/.config/claude-multi-account/chrome-off`, so from a shell `touch` it to turn access off and `rm` it to turn it back on. While access is on, a globe beside a copy's name in the panel shows it used Chrome in the last minute.

- Chrome must be open with the Claude extension installed. If several Chrome profiles have the extension, it uses the one whose helper started last; `--socket` picks another (the sockets are in `/tmp/claude-mcp-browser-bridge-<you>/`).
- The copy whose account the extension is signed in to has both the built-in Claude in Chrome tools and these.
- It leaves out picking between browsers, uploading files or images from the chat, GIF recording and shortcuts.
- The `claude-b`… commands from `--claude-code` each have their own settings folder, so add it to each one the same way (`claude-b mcp add --scope user …`). Their tab groups are called "Claude"; pass `--label` after the path to name them.
- Only the Code tab is tested. A copy's chat could use it from that copy's `claude_desktop_config.json`; `--label` names its tab group something else.

Anthropic doesn't support this. It relies on how the extension and its helper work today: the extension already refuses these local commands when a company manages it, and an update could do the same for everyone. Any copy that has it can drive your Chrome profile, signed-in sites included. Remove it with `claude mcp remove --scope user chrome-relay`.

## How it works

Claude is an Electron app. Electron keeps everything for one account (login cookies, settings, window state) in a single data folder, `~/Library/Application Support/Claude`. If you start Claude with `--user-data-dir=<another folder>`, that copy runs separately with its own login.

There are two catches:

1. **Claude doesn't stop a duplicate.** Opening Claude again while a copy is already running on the same folder starts a second copy on that folder, and two copies on one folder can corrupt it. The launchers (`files/claude-profile.sh` inside each) bring an open copy to the front instead of starting another one.
2. **macOS sends every `claude://` link to the copy that started first.** That includes the sign-in link, so on its own, signing in to B would try to sign A in instead. Claude Notch takes those links and passes each one to the copy you used last. It takes them when it starts, and again whenever a Claude copy starts, in case a Claude update took them back.

## Checking it

Run the tests from `apps/notch` with `swift test`. The app's binary takes a few options for checking it by eye:

```bash
apps/notch/build/"Claude Notch.app"/Contents/MacOS/ClaudeNotch --demo --pin
```

- `--demo` shows six made-up copies (A to F) in every state (out for the week, rate-limited, login expired, signed out, Keychain refused, and so on) instead of yours, then shows a switch peek and a limit alert. It reads nothing, keeps its settings apart from the app's, and leaves the outline and links to the running app. Its ⌥⌘ keys and rows only move which made-up copy is current, and the keys work only while the app itself isn't running;
- `--pin` keeps the panel open;
- `--no-notch` draws the pill used on screens without a notch;
- `--welcome` opens on the welcome page, as the first run does;
- `--snapshot <file.png>` renders the rings, the peeks, the open panel and its settings to a picture and quits (with `--welcome`, the welcome page too).

`--demo` never writes the usage file. To check `claude-usage --cached`, `--best` and `--statusline` without Claude Notch, point `CLAUDE_NOTCH_SNAPSHOT` at a file of your own.

Without `--demo` or `--snapshot`, a second copy quits at once if Claude Notch is already running. `apps/notch/scripts/build-app.sh` builds the app, `claude-usage` and `claude-chrome-relay` on their own; add `--install` to install and open the app, or `--uninstall` to quit and remove it.

What went wrong, if anything, is in the system log:

```bash
log show --predicate 'subsystem == "com.godzillaaa.claude-notch"' --last 1h --info
```

## Updates

Claude.app isn't modified, so it updates itself as normal, and every copy runs the same updated app. When an update installs, quit and reopen **all** the copies. Otherwise any that didn't restart keeps running the old version.

To update Claude Notch, `git pull` and run `install.sh` again, or paste the install line again. If something isn't working, `~/claude-multi-account/install.sh --doctor` checks the whole setup, changes nothing, and says how to fix each problem.

## Moving from Hammerspoon

Earlier versions of this guide used Hammerspoon for the menu bar label, outline and hotkeys, plus a separate "Claude Link Router" app for links. Claude Notch does all of that now, so once it's installed:

```bash
hs -c 'hs.autoLaunch(false)'; osascript -e 'quit app "Hammerspoon"'
mv ~/.hammerspoon/init.lua ~/.hammerspoon/init.lua.retired
rm -rf ~/Applications/"Claude Link Router.app"
```

Then open Claude Notch again so it takes the links back. If Hammerspoon has nothing else to do, uninstall it with `brew uninstall --cask hammerspoon`. The old `init.lua` and link router are in this repo's history (commit `a1fc8f6`).

## Uninstall

```bash
~/claude-multi-account/install.sh --uninstall
```

This quits Claude Notch, takes it out of your login items and deletes it, deletes the launchers, profiles.json, the app's settings and its usage file, and hands `claude://` links back to Claude. It removes the `~/.local/bin/claude-usage` link, Claude Code's status line and the `claude-a`, `claude-b`… commands only if they're the ones `install.sh` added. It leaves each extra copy's data folder, so those copies stay signed in if you install again, and prints the command that deletes them (which signs them out and deletes their settings).

## Files

| File | Goes to | Does |
| --- | --- | --- |
| `bootstrap.sh` | served as the site's `/install.sh` | The one-line install: checks the Mac, clones or pulls this repository, runs `install.sh` |
| `install.sh` | | Sets everything up, adds copies, the status line or `claude-a`, `claude-b`…, or takes it all out; `--doctor` checks it all |
| `scripts/doctor.sh` | | `install.sh --doctor` |
| `files/claude-profile.sh` | inside each launcher app | Brings a copy to the front, or starts it |
| `files/profiles.json` | `~/.config/claude-multi-account/profiles.json` | Each copy's label, colour and hotkey |
| `apps/notch/` | `~/Applications/Claude Notch.app` | The app (limits, hotkeys, outline, links), the `claude-usage` command and `claude-chrome-relay` |
