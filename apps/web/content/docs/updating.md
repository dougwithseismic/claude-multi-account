---
title: Updating and uninstalling
description: Update with a pull and a re-run, uninstall in one command, and move off the older Hammerspoon setup.
section: Help
order: 12
---

## Update Claude Notch

```bash
cd ~/claude-multi-account && git pull && ./install.sh
```

Or paste the [install line](/docs/install) again, which does the same. It keeps your profiles.json, settings and logins. The [changelog](/changelog) says what's new.

## Update Claude

Claude.app updates itself as normal, and every copy runs the updated app. When an update installs, quit and reopen **all** the copies; any you don't restart keeps running the old version.

## Uninstall

```bash
~/claude-multi-account/install.sh --uninstall
```

This quits Claude Notch, takes it out of your login items and deletes it, deletes the launchers, profiles.json, the app's settings and its usage file, and hands `claude://` links back to Claude. It removes the `~/.local/bin/claude-usage` link and Claude Code's status line only if they're the ones `install.sh` added.

It leaves each extra copy's data folder, so those copies stay signed in if you install again, and prints the command that deletes them. Deleting a data folder signs that copy out and deletes its settings and local history.

## Moving from Hammerspoon

Earlier versions of this guide used Hammerspoon for the menu bar label, outline and hotkeys, plus a separate "Claude Link Router" app for links. Claude Notch does all of that now, so once it's installed:

```bash
hs -c 'hs.autoLaunch(false)'; osascript -e 'quit app "Hammerspoon"'
```

```bash
mv ~/.hammerspoon/init.lua ~/.hammerspoon/init.lua.retired
rm -rf ~/Applications/"Claude Link Router.app"
```

Then open Claude Notch again so it takes the links back. If Hammerspoon has nothing else to do, uninstall it with `brew uninstall --cask hammerspoon`.
