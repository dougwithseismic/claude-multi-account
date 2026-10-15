# Two Claude accounts side by side on a Mac

Run the Claude desktop app twice, each copy signed in to a different account, and always know which one you're in.

When you're done you have:

- **Claude A**: your normal Claude, using the usual data folder.
- **Claude B**: a second copy with its own data folder, so it has its own login and settings.
- **A label in the menu bar**: "● Claude A" (blue) or "● Claude B" (orange) for whichever is in front, plus a coloured outline round its window.
- **⌥⌘1 / ⌥⌘2**: switch to A or B, starting it if it's closed.
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

## 1. Make B's data folder

```bash
mkdir -p "$HOME/Library/Application Support/Claude-B"
chmod 700 "$HOME/Library/Application Support/Claude-B"
```

Optional: copy over A's app preferences and DevTools setting. Don't copy `config.json`, because that's where A's login lives.

```bash
SRC="$HOME/Library/Application Support/Claude"
cp -p "$SRC/claude_desktop_config.json" "$SRC/developer_settings.json" "$HOME/Library/Application Support/Claude-B/" 2>/dev/null
```

The MCP servers and skills the Code tab uses live in `~/.claude`, which both copies share, so there's nothing to copy for those. Transcripts and memory are shared too, which is useful, but don't run both accounts in the same git worktree at once.

## 2. Build the launchers

`files/claude-profile.sh A|B` brings that copy to the front if it's running and starts it if it isn't. Wrap it in two small apps so you can open them from Spotlight, Raycast or the Dock:

```bash
ICON=/Applications/Claude.app/Contents/Resources/$(/usr/libexec/PlistBuddy -c "Print CFBundleIconFile" /Applications/Claude.app/Contents/Info.plist | sed 's/\.icns$//').icns
mkdir -p ~/Applications
for X in A B; do
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

From now on, never open `/Applications/Claude.app` directly while a copy is running. Use Claude A and Claude B.

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
3. To show account names instead of "Claude A" / "Claude B", change the two `label =` lines at the top of `~/.hammerspoon/init.lua`, then choose **Reload Config** from the hammer icon in the menu bar.

The config tells the copies apart by checking whether a copy was started with `Claude-B` in its arguments, so it keeps working after restarts and updates.

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

## 5. Sign in to B

1. Open **Claude B** (⌥⌘2). The menu bar should say "● Claude B".
2. Click sign in and finish in the browser.
3. When the browser asks to open Claude, allow it. The login goes to B.

Don't click into A between steps 2 and 3, or A becomes "last used" and receives the login.

You only need to do this once. B stays signed in after that.

Optional: give the two copies different themes (Settings → Appearance), for example A in Light and B in Dark, so you can tell them apart even without the outline.

## Day to day

- **⌥⌘1** switches to A and **⌥⌘2** to B, or click the menu bar label and choose from the menu.
- "●" means that Claude is in front. A grey "○" means you're in another app, and it shows the Claude you used last, which is where the next `claude://` link will go.
- **Claude in Chrome:** there's one Chrome and one extension, and the connection to it belongs to your Mac user rather than to a Claude account. So both copies can use the same Chrome; just don't have both driving it at the same time.
- **Built-in browser pane:** this is separate per copy, so B's doesn't have A's site logins.
- Both copies write to the same log, `~/Library/Logs/Claude/main.log`.

## Updates

Claude.app isn't modified, so it updates itself as normal, and both copies run the same updated app. When an update installs, quit and reopen **both** copies. Otherwise the one that didn't restart keeps running the old version.

## Undo

```bash
hs -c 'hs.urlevent.setDefaultHandler("claude", "com.anthropic.claudefordesktop")'
rm -rf ~/Applications/"Claude A.app" ~/Applications/"Claude B.app" ~/Applications/"Claude Link Router.app"
rm -rf "$HOME/Library/Application Support/Claude-B"   # signs B out and deletes its settings
```

Then quit Hammerspoon and delete `~/.hammerspoon/init.lua`, or uninstall Hammerspoon with `brew uninstall --cask hammerspoon`.

## Files

| File | Goes to | Does |
| --- | --- | --- |
| `files/claude-profile.sh` | inside each launcher app | Brings copy A or B to the front, or starts it |
| `files/init.lua` | `~/.hammerspoon/init.lua` | Menu bar label, window outline, ⌥⌘1/⌥⌘2, link handoff |
| `files/claude-link-router.applescript` | `~/Applications/Claude Link Router.app` | Owns `claude://` and passes links to Hammerspoon |
