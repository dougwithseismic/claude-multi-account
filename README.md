# Several Claude accounts side by side on a Mac

Run the Claude desktop app two or more times, each copy signed in to a different account, and always know which one you're in. This guide sets up three (A, B and C); add more the same way.

When you're done you have:

- **Claude A**: your normal Claude, using the usual data folder.
- **Claude B** and **Claude C**: extra copies, each with its own data folder (`Claude-B`, `Claude-C`), so each has its own login and settings.
- **A label in the menu bar**: "● Claude A" (blue), "● Claude B" (orange) or "● Claude C" (green) for whichever is in front, plus a coloured outline round its window.
- **⌥⌘1 / ⌥⌘2 / ⌥⌘3**: switch to A, B or C, starting it if it's closed.
- **A link router**: `claude://` links, including sign-in, go to the Claude you used last instead of always going to A.

Claude.app itself is never modified, so it stays signed and keeps updating as normal.

The scripts are in `files/`. Run every command from this folder:

```bash
cd ~/Documents/WEB_PROJECTS/tools/claude-multi-account
```

## How it works

Claude is an Electron app. Electron keeps everything for one account (login cookies, settings, window state) in a single data folder, `~/Library/Application Support/Claude`. If you start Claude with `--user-data-dir=<another folder>`, that copy runs separately with its own login.

There are two catches, and the steps below deal with both:

1. **Claude doesn't stop a duplicate.** Opening Claude again while a copy is already running on the same folder starts a second copy on that folder, and two copies on one folder can corrupt it. That's why you use the launchers in step 2, which bring an open copy to the front instead of starting another one.
2. **macOS sends every `claude://` link to the copy that started first.** That includes the sign-in link, so without the router (step 4) signing in to B would try to sign A in instead.

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

## 3. Install Hammerspoon for the label, outline and hotkeys

[Hammerspoon](https://www.hammerspoon.org) is a free macOS automation tool that you configure with a Lua file.

```bash
brew install --cask hammerspoon
mkdir -p ~/.hammerspoon
cp files/init.lua ~/.hammerspoon/init.lua
open -a Hammerspoon
```

Then:

1. In **System Settings → Privacy & Security → Accessibility**, turn **Hammerspoon** on. The window outline needs this; the label and hotkeys work without it.
2. Make it start at login. Either tick "Launch Hammerspoon at login" in its Preferences, or run `hs -c 'hs.autoLaunch(true)'`. The `hs` command works because `init.lua` loads `hs.ipc`.
3. To show account names instead of "Claude A" / "B" / "C", change the `label =` lines at the top of `~/.hammerspoon/init.lua`, then choose **Reload Config** from the hammer icon in the menu bar.

The config tells the copies apart by reading which `Claude-<letter>` folder a copy was started with (none means A), so it keeps working after restarts and updates.

## 4. Install the link router

`files/claude-link-router.applescript` receives `claude://` links and asks Hammerspoon (`claudeAB.openURL`) to deliver each one to the Claude you used last. If Hammerspoon isn't running, the link goes to A as usual.

```bash
APP=~/Applications/"Claude Link Router.app"
rm -rf "$APP"
osacompile -o "$APP" files/claude-link-router.applescript
P="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.godzillaaa.claude-link-router" "$P" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.godzillaaa.claude-link-router" "$P"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$P"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" \
  -c "Add :CFBundleURLTypes:0 dict" \
  -c "Add :CFBundleURLTypes:0:CFBundleURLName string Claude links" \
  -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" \
  -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string claude" "$P"
codesign --force --deep -s - "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
hs -c 'hs.urlevent.setDefaultHandler("claude", "com.godzillaaa.claude-link-router")'
```

Check it worked: `hs -c 'return hs.urlevent.getDefaultHandler("claude")'` should print `com.godzillaaa.claude-link-router`.

Hammerspoon claims `claude://` back every time it loads and every time Claude starts, in case a Claude update takes it.

## 5. Sign in to B and C

Do this once for each extra copy, one at a time:

1. Open it (⌥⌘2 for B, ⌥⌘3 for C). The menu bar should name it.
2. Click sign in and finish in the browser.
3. When the browser asks to open Claude, allow it. The login goes to the copy you opened.

Don't click into another Claude between steps 2 and 3, or that one becomes "last used" and receives the login.

Each copy stays signed in after that.

Optional: give the two copies different themes (Settings → Appearance), for example A in Light and B in Dark, so you can tell them apart even without the outline.

## Day to day

- **⌥⌘1**, **⌥⌘2** and **⌥⌘3** switch to A, B and C, or click the menu bar label and choose from the menu.
- Closing a Claude window doesn't quit that copy: it keeps running with no window, as Mac apps do. The hotkeys and launchers handle this by sending it the same "reopen" message a Dock click sends, so a new window appears. To really quit a copy, press ⌘Q in it.
- "●" means that Claude is in front. A grey "○" means you're in another app, and it shows the Claude you used last, which is where the next `claude://` link will go.
- **Claude in Chrome:** there's one Chrome and one extension, and the connection to it belongs to your Mac user rather than to a Claude account. So every copy can use the same Chrome; just don't have two driving it at the same time.
- **Built-in browser pane:** this is separate per copy, so each copy has its own site logins there.
- All copies write to the same log, `~/Library/Logs/Claude/main.log`.

## Each account's limits (`claude-usage`)

`notch/` holds the start of a notch app that shows every account's 5-hour and weekly limits ([PRD](docs/notch-prd.md)). Its first piece is a command that prints them:

```bash
cd notch && swift build -c release && .build/release/claude-usage
```

The first run asks for Keychain access to "Claude Safe Storage". Click Always Allow: it reads the key each Claude copy uses to encrypt its own login. It only reads. It never refreshes a login or changes Claude's files, and its only network calls are the usage and profile checks Claude Code's `/usage` makes. Add `--json` for machine-readable output, or `--only B,C` to choose accounts. Run the tests with `swift test`.

## Updates

Claude.app isn't modified, so it updates itself as normal, and every copy runs the same updated app. When an update installs, quit and reopen **all** the copies. Otherwise any that didn't restart keeps running the old version.

## Adding a fourth (D, E, …)

1. Add a line to `PROFILES` at the top of `~/.hammerspoon/init.lua`, for example `D = { label = "Claude D", color = { hex = "#B04FD6" }, key = "4" },`, then Reload Config.
2. Build its launcher: run the loop in step 2 with `for X in D; do`.
3. Open it with ⌥⌘4 and sign in as in step 5.

Each copy is a full Electron app, so expect roughly 0.5–1 GB of memory per open copy.

## Undo

```bash
hs -c 'hs.urlevent.setDefaultHandler("claude", "com.anthropic.claudefordesktop")'
rm -rf ~/Applications/"Claude A.app" ~/Applications/"Claude B.app" ~/Applications/"Claude C.app" ~/Applications/"Claude Link Router.app"
rm -rf "$HOME/Library/Application Support/Claude-B" "$HOME/Library/Application Support/Claude-C"   # signs B and C out and deletes their settings
```

Then quit Hammerspoon and delete `~/.hammerspoon/init.lua`, or uninstall Hammerspoon with `brew uninstall --cask hammerspoon`.

## Files

| File | Goes to | Does |
| --- | --- | --- |
| `files/claude-profile.sh` | inside each launcher app | Brings a copy to the front, or starts it |
| `files/init.lua` | `~/.hammerspoon/init.lua` | Menu bar label, window outline, ⌥⌘1/2/3, link handoff |
| `files/claude-link-router.applescript` | `~/Applications/Claude Link Router.app` | Owns `claude://` and passes links to Hammerspoon |
