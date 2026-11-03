---
title: Troubleshooting
description: The install failed, a sign-in went to the wrong copy, a ring is missing, or the numbers look stale. What to check, in order.
section: Help
order: 11
---

## Check the setup

One command checks everything Claude Notch needs, changes nothing, and says how to fix whatever is wrong:

```bash
~/claude-multi-account/install.sh --doctor
```

It checks macOS, Claude.app and Swift; your profiles.json; each copy's data folder, launcher and sign-in; whether a copy is open twice on one folder; whether Claude Notch is installed, up to date, running and opening at login; where `claude://` links go; that the Keychain item is there (without reading it); how recently usage was read; once you have them, that each of `claude-a`, `claude-b`… has its folder; and, with [Claude in Chrome](/docs/chrome) set up, which folders have the relay and whether Chrome's helper is running. It ends with "Everything looks right" or the number of things to fix.

## Find out what went wrong

Claude Notch logs what failed, and nothing else, to the system log. `claude-chrome-relay` logs there too, under the category `chrome-relay`:

```bash
log show --predicate 'subsystem == "com.godzillaaa.claude-notch"' --last 1h --info
```

And `claude-usage` shows what each copy's login looks like from the terminal:

```bash
~/claude-multi-account/apps/notch/build/claude-usage --verbose
```

## The install stopped

| install.sh says | Fix |
| --- | --- |
| this is for macOS / needs macOS 26 or later | Claude Notch uses macOS 26's notch and window APIs, so it can't run on an older system |
| install the Claude desktop app in /Applications first | [Download Claude](https://claude.ai/download) and drag it to `/Applications`, not `~/Applications` |
| install Apple's Command Line Tools first, or needs Apple's Command Line Tools | Finish the installer it opened (or run `xcode-select --install`), then run the same command again |
| needs Swift 6.2 or later | Update the Command Line Tools in System Settings → General → Software Update, or install them again with `xcode-select --install` |
| the Command Line Tools are there but Swift won't run | If what it shows mentions a licence, run `sudo xcodebuild -license accept`. Otherwise `sudo xcode-select --reset` |
| another ./install.sh is running | Wait for the other one to finish. Two at once would each replace the launchers and the app |
| ~/claude-multi-account is there but isn't a copy of Claude Notch | Something else has that name. Rename it, then paste the install line again |
| It has changes of its own, so it wasn't updated | You've edited files in `~/claude-multi-account`. It installs from them as they are; to update, undo or stash your changes (`git -C ~/claude-multi-account status` lists them) |
| It couldn't be fast-forwarded to the latest version | `~/claude-multi-account` is on a branch of its own, or has commits the latest version doesn't. It installs what's there; `git -C ~/claude-multi-account pull` says why it can't update |
| …isn't a JSON list of profiles | Your `profiles.json` has a typo. Fix it, or move it aside and the installer writes a new one |
| couldn't build / couldn't sign | Run it again; if it fails twice, [open an issue](https://github.com/dougwithseismic/claude-multi-account/issues) with the output |

`install.sh` is safe to run as often as you like. It keeps your profiles.json, settings and logins.

## A sign-in went to the wrong copy

Sign-in links go to the copy you used last. If you clicked into another Claude while the browser was signing in, that one got the login.

1. In the copy that got the wrong login, sign out (account menu → Log out) if it was signed in to a different account before.
2. Switch to the copy you meant with its hotkey, so it's the one used last.
3. Start the sign-in again from that copy, and don't click any other Claude until the browser hands back.

If a peek says the copy **didn't get the link**, macOS isn't letting Claude Notch pass links on. System Settings opens at Privacy & Security → Automation: turn on Claude under Claude Notch, then sign in again.

If links keep going to A whatever you do, macOS has given them back to Claude, which can happen after a Claude update. Quit and reopen Claude Notch: it takes them back when it starts, and again whenever a copy of Claude starts.

## A copy's ring is missing

- It isn't in the Copies window (the gear, then **Manage…** under Copies): add it there. A letter you add to `profiles.json` by hand works too, once the file is saved.
- Settings says profiles.json isn't a JSON list of profiles: there's a typo, often a missing comma. The copies in use stay until it's fixed and saved.
- The window says **Not made yet**: click **Make**, or run `install.sh`, to make its data folder and launcher.

## The numbers look old

- **Greyed, "Open Claude B to update":** that copy's login expired while it was closed. Open it; it renews its own login and the next read works. Claude Notch never renews a login itself, because that would sign the copy out.
- **"retrying in 20m":** Anthropic is rate-limiting the usage check. Claude Notch backs off, 5 minutes at first and up to 6 hours, and shows the last good numbers with their age. Nothing to do.
- **Dimmed, with an age like "8h ago":** the numbers are from before a sleep, or reads have been failing for over 15 minutes. After a sleep the next read comes within seconds, and one that fails because the network isn't back is tried again 30 seconds later.
- **The footer's "Updated" is old:** click the refresh button at the top of the panel. It re-reads any copy older than a minute.

## The Keychain keeps asking

macOS ties **Always Allow** to the app's signature. If no code-signing certificate is found, each build is signed ad hoc and has a new signature, so macOS asks again after every update. Create a local code-signing certificate in Keychain Access (Certificate Assistant → Create a Certificate, type Code Signing), then run `install.sh` again. Or set `CODESIGN_IDENTITY` to a certificate you already have.

## Two copies opened on the same folder

That happens when `/Applications/Claude.app` is opened directly while a copy is running. Quit both with <kbd>⌘Q</kbd>, then open the copy you want with its hotkey or launcher. From then on use the hotkeys or launchers, not Claude.app.

## Claude Code's status line

- **"Claude Notch isn't running"**, in grey: there's no usage file yet. Open Claude Notch; the line fills in after its first read.
- **"usage 20m old"**: Claude Notch hasn't written its file for that long, so it isn't running, or the Mac was asleep. Check it's open. While it's running but waiting (on a rate limit, say), the line shows each copy's last numbers, dimmed. `--doctor` says when it last read.
- **Nothing changed after `--statusline`:** you already had a status line, so it was left alone and `install.sh` printed the setting to use. [Claude Code's status line](/docs/status-line) shows how to have both.
- **No "Code" at the start:** Claude Code passes the session's own limits on Pro and Max plans, after the session's first answer.

## Claude Code in the terminal

- **`claude-b: command not found`:** `~/.local/bin` isn't on your PATH. Type `~/.local/bin/claude-b`, or add the folder to your PATH in `~/.zshrc`.
- **`claude-b` asks you to sign in:** it's the first run on `~/.claude-B`, or that login was signed out. Sign in with Claude B's account. `claude-b auth status` says which account it has.
- **`claude-b` doesn't have a skill or setting `claude` has:** it's linked from `~/.claude` only if the folder didn't have its own. Remove the folder's own one and run `./install.sh --claude-code` again to link it.
- **The terminal's Claude Code keeps changing account:** one report says the Claude Code inside the desktop app can overwrite the terminal's login in the Keychain ([anthropics/claude-code#101990](https://github.com/anthropics/claude-code/issues/101990)). `claude-b auth status` shows which account each one has.

## Claude in Chrome

- **"Chrome isn't reachable on this Mac":** Chrome is closed, or the Claude extension isn't installed in it. Open Chrome; the extension starts its helper with it. If Chrome is already open, restart it. `claude-chrome-relay --check` says whether the helper is running.
- **"Chrome access is switched off in Claude Notch":** turn **Chrome access for every copy** back on in settings, or `rm ~/.config/claude-multi-account/chrome-off`.
- **A session has no `mcp__chrome-relay__` tools:** it started before `install.sh --chrome`. Start a new one. For `claude-b` and the rest, run `./install.sh --chrome` again after `--claude-code` so their folders get it too.
- **It works in the wrong Chrome profile:** with the extension in several profiles, the relay uses the helper that started last. Quit the other profiles' windows and restart Chrome, or pass `--socket` ([Claude in Chrome](/docs/chrome#good-to-know)).
- **"Chrome didn't answer in time":** the page may still have done what was asked. Check it before trying again.

## Still stuck

[Open an issue](https://github.com/dougwithseismic/claude-multi-account/issues) with what you did, what you expected, and the output of the two commands at the top of this page. Remove any emails first.
