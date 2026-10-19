---
title: Troubleshooting
description: The install failed, a sign-in went to the wrong copy, a ring is missing, or the numbers look stale. What to check, in order.
section: Help
order: 8
---

## Find out what went wrong

Claude Notch logs what failed, and nothing else, to the system log:

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
| install Apple's Command Line Tools first | Run `xcode-select --install`, wait for it to finish, then run `install.sh` again |
| …isn't a JSON list of profiles | Your `profiles.json` has a typo. Fix it, or move it aside and the installer writes a new one |
| couldn't build / couldn't sign | Run it again; if it fails twice, [open an issue](https://github.com/dougwithseismic/claude-multi-account/issues) with the output |

`install.sh` is safe to run as often as you like. It keeps your profiles.json, settings and logins.

## A sign-in went to the wrong copy

Sign-in links go to the copy you used last. If you clicked into another Claude while the browser was signing in, that one got the login.

1. In the copy that got the wrong login, sign out (account menu → Log out) if it was signed in to a different account before.
2. Switch to the copy you meant with its hotkey, so it's the one used last.
3. Start the sign-in again from that copy, and don't click any other Claude until the browser hands back.

If links keep going to A whatever you do, macOS has given them back to Claude, which can happen after a Claude update. Quit and reopen Claude Notch: it takes them back when it starts, and again whenever a copy of Claude starts.

## A copy's ring is missing

- The copy has never been started: open it once with its hotkey or launcher.
- Its letter isn't in `profiles.json`: run `install.sh` with the number of copies you want, or add it by hand and click **Reload** in settings.
- The data folder is missing: `install.sh` makes it again.

## The numbers look old

- **Greyed, "Open Claude B to update":** that copy's login expired while it was closed. Open it; it renews its own login and the next read works. Claude Notch never renews a login itself, because that would sign the copy out.
- **"retrying in 20m":** Anthropic is rate-limiting the usage check. Claude Notch backs off, 5 minutes at first and up to 6 hours, and shows the last good numbers with their age. Nothing to do.
- **The footer's "Updated" is old:** click the refresh button at the top of the panel. It re-reads any copy older than a minute.

## The Keychain keeps asking

macOS ties **Always Allow** to the app's signature. If no code-signing certificate is found, each build is signed ad hoc and has a new signature, so macOS asks again after every update. Create a local code-signing certificate in Keychain Access (Certificate Assistant → Create a Certificate, type Code Signing), then run `install.sh` again. Or set `CODESIGN_IDENTITY` to a certificate you already have.

## Two copies opened on the same folder

That happens when `/Applications/Claude.app` is opened directly while a copy is running. Quit both with <kbd>⌘Q</kbd>, then open the copy you want with its hotkey or launcher. From then on use the hotkeys or launchers, not Claude.app.

## Still stuck

[Open an issue](https://github.com/dougwithseismic/claude-multi-account/issues) with what you did, what you expected, and the output of the two commands at the top of this page. Remove any emails first.
