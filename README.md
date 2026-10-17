# Several Claude accounts side by side on a Mac

Run the Claude desktop app two or more times, each copy signed in to a different account, and always know which one you're in. This guide sets up three (A, B and C); add more the same way.

When you're done you have:

- **Claude A**: your normal Claude, using the usual data folder.
- **Claude B** and **Claude C**: extra copies, each with its own data folder (`Claude-B`, `Claude-C`), so each has its own login and settings.
- **Claude Notch**, a small app of ours that:
  - shows every account's 5-hour and weekly limits at the MacBook notch;
  - switches to A, B or C with **⌥⌘1 / ⌥⌘2 / ⌥⌘3**, starting it if it's closed;
  - draws an outline in that account's colour (blue, orange or green) round the window of whichever Claude is in front;
  - sends `claude://` links, including sign-in, to the Claude you used last instead of always to A.

Claude.app itself is never modified, so it stays signed and keeps updating as normal.

The scripts are in `files/` and the app is in `apps/notch/`. Run every command from this folder:

```bash
cd ~/Documents/WEB_PROJECTS/tools/claude-multi-account
```

## How it works

Claude is an Electron app. Electron keeps everything for one account (login cookies, settings, window state) in a single data folder, `~/Library/Application Support/Claude`. If you start Claude with `--user-data-dir=<another folder>`, that copy runs separately with its own login.

There are two catches, and the steps below deal with both:

1. **Claude doesn't stop a duplicate.** Opening Claude again while a copy is already running on the same folder starts a second copy on that folder, and two copies on one folder can corrupt it. That's why you use the launchers in step 2, which bring an open copy to the front instead of starting another one.
2. **macOS sends every `claude://` link to the copy that started first.** That includes the sign-in link, so on its own, signing in to B would try to sign A in instead. Claude Notch (step 3) takes those links and passes each one to the copy you used last.

## 1. Make the data folders

The launcher script creates these on first use, but you can make them yourself:

```bash
for X in B C; do
  mkdir -p "$HOME/Library/Application Support/Claude-$X"
  chmod 700 "$HOME/Library/Application Support/Claude-$X"
done
```

Optional: copy over A's app preferences and DevTools setting. Don't copy `config.json`, because that's where A's login lives.

```bash
SRC="$HOME/Library/Application Support/Claude"
for X in B C; do cp -p "$SRC/claude_desktop_config.json" "$SRC/developer_settings.json" "$HOME/Library/Application Support/Claude-$X/" 2>/dev/null; done
```

The MCP servers and skills the Code tab uses live in `~/.claude`, which both copies share, so there's nothing to copy for those. Transcripts and memory are shared too, which is useful, but don't run both accounts in the same git worktree at once.

## 2. Build the launchers

`files/claude-profile.sh A|B|C` brings that copy to the front if it's running and starts it if it isn't. A uses Claude's normal folder; any other letter X uses `Claude-X`. Wrap it in small apps so you can open them from Spotlight, Raycast or the Dock:

```bash
ICON=/Applications/Claude.app/Contents/Resources/$(/usr/libexec/PlistBuddy -c "Print CFBundleIconFile" /Applications/Claude.app/Contents/Info.plist | sed 's/\.icns$//').icns
mkdir -p ~/Applications
for X in A B C; do
  APP=~/Applications/"Claude $X.app"
  echo "do shell script quoted form of (POSIX path of (path to me)) & \"Contents/Resources/claude-profile.sh $X\"" > /tmp/claude-$X.applescript
  rm -rf "$APP"
  osacompile -o "$APP" /tmp/claude-$X.applescript
  install -m 755 files/claude-profile.sh "$APP/Contents/Resources/claude-profile.sh"
  cp "$ICON" "$APP/Contents/Resources/applet.icns"
  /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$APP/Contents/Info.plist"
  codesign --force --deep -s - "$APP"
done
```

`LSUIElement` stops the launchers showing up in the Dock; they quit as soon as they've done their job. Re-signing is needed because editing `Info.plist` breaks `osacompile`'s signature.

From now on, never open `/Applications/Claude.app` directly while a copy is running. Use the Claude A, B and C launchers.

## 3. Install Claude Notch

```bash
apps/notch/scripts/build-app.sh --install
```

This builds the app, copies it to `~/Applications/Claude Notch.app` and opens it. It has no Dock icon; quit it from its panel. Then:

1. **Keychain:** the first run asks for access to "Claude Safe Storage". Click **Always Allow** (it asks for your login password). Each Claude copy encrypts its own login with that key, and the app reads the login to check usage. The script signs the app with your first code-signing certificate (or `CODESIGN_IDENTITY`), so later rebuilds don't ask again. With no certificate it signs ad hoc, and every rebuild asks again.
2. **Login:** the first run from `~/Applications` adds it to your login items (macOS shows a notification). Turn off **Open at login** in its settings (the gear at the top left of the panel) to stop that.
3. **Links:** it takes `claude://` links when it starts, and again whenever a Claude copy starts, in case a Claude update took them back. The first link it passes on makes macOS ask whether "Claude Notch" may control "Claude". Click **Allow**.

Hotkeys, the outline and links need no Accessibility permission.

### What it shows

By default it stays collapsed: one double ring per Claude copy just right of the notch, in that copy's colour. The outer ring is the 5-hour window and the inner one the fullest weekly window. A red cross means that account is out for the week. A dot under a ring marks the copy in front. The rings never take clicks, so the menu bar icons under them still work. On a screen without a notch the rings sit in a small black pill at the top centre.

Rest the pointer on the notch, or click it, and the panel grows out of it with one row per copy: its name, plan, each window's bar and when it resets. The white tick on a bar marks how far through its window it is, so a bar past its tick is going faster than an even pace. Click a row to switch to that Claude. Move away and the panel folds back into the notch.

- **Privacy:** rows show the profile's name ("Claude B") and plan, not the email or a Team's name, so the panel can open in front of anyone. The eye at the top left shows them; holding ⌥ over the panel shows them until you let go.
- **Peeks:** after a ⌥⌘ switch, a strip under the notch names the copy for a moment. When the copy in use passes 90% of its 5-hour limit, runs out of a limit, or gets one back, the strip says so for a few seconds. Peeks never take clicks and stay away while an app is full screen.
- **Settings** (the gear): show emails and team names, open on hover or only on click, limit alerts, switch peeks, haptic feedback, open at login, and editing profiles.json.

**Teams and other organizations:** one login can belong to several organizations, for example a personal Max plan and a Team. Each has its own limits. The row shows the one that copy is working in (whichever you last picked in Claude's account menu), and any other organization below it, marked "not in use". Claude renews only the login of the organization it's working in. So if another one's numbers go stale, switch that Claude to it once to update them. An organization you've never used in that copy (a free personal plan, say) has no login and isn't shown.

It reads every account at launch and then every 5 minutes, and backs off when Anthropic rate-limits the check. It only reads: it never refreshes a login or changes Claude's files. Its only network calls are the usage and profile checks Claude Code's `/usage` makes.

### Names, colours and keys

`~/.config/claude-multi-account/profiles.json` sets each copy's label, colour and hotkey; `files/profiles.json` is the starting point:

```bash
mkdir -p ~/.config/claude-multi-account
cp files/profiles.json ~/.config/claude-multi-account/profiles.json
```

```json
[
  { "letter": "A", "label": "Claude A", "color": "#2F7BF5", "hotkey": "1" },
  { "letter": "B", "label": "Claude B", "color": "#F5822F", "hotkey": "2" },
  { "letter": "C", "label": "Claude C", "color": "#2FB36B", "hotkey": "3" }
]
```

Without the file the app uses these. **Edit** under Profiles in its settings opens the file, writing these defaults out first if there's none, and **Reload** applies your changes. `claude-usage` reads it too.

### `claude-usage`

The same numbers in the terminal. `build-app.sh` builds it into `apps/notch/build/claude-usage`:

```bash
apps/notch/build/claude-usage
```

Its first run asks for Keychain access too. Add `--json` for machine-readable output, `--only B,C` to choose accounts, or `--verbose` to see where each copy's organization in use was read from. Run the tests with `cd apps/notch && swift test`.

### Checking it

The app's binary takes a few options for checking it by eye:

```bash
apps/notch/build/"Claude Notch.app"/Contents/MacOS/ClaudeNotch --demo --pin
```

- `--demo` shows six made-up copies (A to F) in every state (out for the week, rate-limited, login expired, signed out, Keychain refused, and so on) instead of yours, then shows a switch peek and a limit alert. It reads nothing, keeps its settings apart from the app's, and leaves the outline and links to the running app. Its ⌥⌘ keys and rows only move which made-up copy is current, and the keys work only while the app itself isn't running;
- `--pin` keeps the panel open;
- `--no-notch` draws the pill used on screens without a notch;
- `--snapshot <file.png>` renders the rings and the open panel to a picture and quits.

Without `--demo` or `--snapshot`, a second copy quits at once if Claude Notch is already running.

What went wrong, if anything, is in the system log:

```bash
log show --predicate 'subsystem == "com.godzillaaa.claude-notch"' --last 1h --info
```

## 4. Sign in to B and C

Do this once for each extra copy, one at a time:

1. Open it (⌥⌘2 for B, ⌥⌘3 for C). Its window gets that copy's outline.
2. Click sign in and finish in the browser.
3. When the browser asks to open Claude, allow it. The login goes to the copy you opened.

Don't click into another Claude between steps 2 and 3, or that one becomes "last used" and receives the login. The notch panel's footer says which copy links go to.

Each copy stays signed in after that.

Optional: give the copies different themes (Settings → Appearance), for example A in Light and B in Dark, so you can tell them apart at a glance.

## Day to day

- **⌥⌘1**, **⌥⌘2** and **⌥⌘3** switch to A, B and C, and a peek under the notch names the one you switched to. So does clicking a row in the notch panel.
- Closing a Claude window doesn't quit that copy: it keeps running with no window, as Mac apps do. Switching handles this by sending it the same "reopen" message a Dock click sends, so a new window appears. To really quit a copy, press ⌘Q in it.
- The outline shows which Claude you're typing into. When another app is in front, the next `claude://` link goes to the Claude you used last ("Links go to Claude B" in the panel).
- **Claude in Chrome:** there's one Chrome and one extension, and the connection to it belongs to your Mac user rather than to a Claude account. So every copy can use the same Chrome; just don't have two driving it at the same time.
- **Built-in browser pane:** this is separate per copy, so each copy has its own site logins there.
- All copies write to the same log, `~/Library/Logs/Claude/main.log`.

## Moving from Hammerspoon

Earlier versions of this guide used Hammerspoon for the menu bar label, outline and hotkeys, plus a separate "Claude Link Router" app for links. Claude Notch does all of that now, so once it's installed:

```bash
hs -c 'hs.autoLaunch(false)'; osascript -e 'quit app "Hammerspoon"'
mv ~/.hammerspoon/init.lua ~/.hammerspoon/init.lua.retired
rm -rf ~/Applications/"Claude Link Router.app"
```

Then open Claude Notch again so it takes the links back. If Hammerspoon has nothing else to do, uninstall it with `brew uninstall --cask hammerspoon`. The old `init.lua` and link router are in this repo's history (commit `a1fc8f6`).

## Updates

Claude.app isn't modified, so it updates itself as normal, and every copy runs the same updated app. When an update installs, quit and reopen **all** the copies. Otherwise any that didn't restart keeps running the old version.

## Adding a fourth (D, E, …)

1. Add a line to `~/.config/claude-multi-account/profiles.json`, for example `{ "letter": "D", "label": "Claude D", "color": "#B04FD6", "hotkey": "4" }`, then click **Reload** under Profiles in Claude Notch's settings.
2. Build its launcher: run the loop in step 2 with `for X in D; do`.
3. Open it with ⌥⌘4 and sign in as in step 4. Its ring appears once it has a data folder.

Each copy is a full Electron app, so expect roughly 0.5–1 GB of memory per open copy.

## Undo

First turn off **Open at login** in Claude Notch's settings and click **Quit** at the bottom of them. Then:

```bash
rm -rf ~/Applications/"Claude Notch.app" ~/.config/claude-multi-account
rm -rf ~/Applications/"Claude A.app" ~/Applications/"Claude B.app" ~/Applications/"Claude C.app"
rm -rf "$HOME/Library/Application Support/Claude-B" "$HOME/Library/Application Support/Claude-C"   # signs B and C out and deletes their settings
```

With Claude Notch gone, macOS hands `claude://` links to Claude itself again.

## Files

| File | Goes to | Does |
| --- | --- | --- |
| `files/claude-profile.sh` | inside each launcher app | Brings a copy to the front, or starts it |
| `files/profiles.json` | `~/.config/claude-multi-account/profiles.json` | Each copy's label, colour and hotkey |
| `apps/notch/` | `~/Applications/Claude Notch.app` | The app (limits, hotkeys, outline, links) and the `claude-usage` command |
