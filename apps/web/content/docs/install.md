---
title: Install
description: One script sets up the extra copies of Claude, their launchers and Claude Notch. It takes a couple of minutes and asks you nothing.
section: Start
order: 1
---

## What you need

- A Mac on **macOS 26** or later.
- The [Claude desktop app](https://claude.ai/download) in `/Applications`.
- Apple's **Command Line Tools** (or Xcode), which build the app on your Mac. If you don't have them, the install line opens their installer; paste it again once that's done.

## Install

Paste this into Terminal:

```bash
curl -fsSL https://dougwithseismic.github.io/claude-multi-account/install.sh | zsh
```

It checks your Mac, gets the code into `~/claude-multi-account` (or updates it, if it's already there and you haven't changed it), and runs the installer. The first build takes a minute or two. When it finishes, the rings appear beside the notch and the script lists what's left for you to do: allow Keychain access, and sign in to each new copy. [Sign in to each copy](/docs/sign-in) walks through both.

### Or read it first

The line runs [`bootstrap.sh`](https://github.com/dougwithseismic/claude-multi-account/blob/main/bootstrap.sh). To do the same by hand, get the code and run the installer yourself:

```bash
git clone https://github.com/dougwithseismic/claude-multi-account.git ~/claude-multi-account
```

```bash
~/claude-multi-account/install.sh
```

> **Tip:** You can also point your coding agent at the repository and ask it to install it. `install.sh` takes no input and is safe to run again, and it ends with the steps only a person at the keyboard can do.

## What the script does

It prints each step as it goes:

1. **Data folders.** Makes one for each extra copy: `~/Library/Application Support/Claude-B` and `Claude-C`. A new folder starts with A's app preferences (`claude_desktop_config.json`, `developer_settings.json`) but never A's login.
2. **Profiles.** Writes `~/.config/claude-multi-account/profiles.json` with each copy's name, colour and hotkey, if you don't have one yet. See [Names, colours and keys](/docs/profiles).
3. **Launchers.** Builds `Claude A.app`, `Claude B.app` and `Claude C.app` in `~/Applications`. Each brings its copy to the front if it's running and starts it if it isn't, so you can open them from Spotlight, Raycast or the Dock.
4. **Claude Notch.** Builds it, installs it as `~/Applications/Claude Notch.app` and opens it. It has no Dock icon; quit it from its panel.

Claude.app itself is never modified, so it stays signed and keeps updating as normal.

## More or fewer copies

It sets up three copies, A, B and C. To have four (A to D), or add D to a setup you already have:

```bash
~/claude-multi-account/install.sh 4
```

Any number from 2 to 26 works. On a Mac without it yet, the install line takes the number too: `curl -fsSL …/install.sh | zsh -s -- 4`. Each copy is a full Claude app, so expect roughly 0.5 to 1 GB of memory for each one you have open.

## One rule from now on

Don't open `/Applications/Claude.app` directly while a copy is running: it would start a second copy on A's folder, and two copies on one folder can corrupt it. Use <kbd>⌥⌘1</kbd>, <kbd>⌥⌘2</kbd> and <kbd>⌥⌘3</kbd>, or the Claude A, B and C launchers.

## Next

- [Sign in to each copy](/docs/sign-in)
- [Day to day](/docs/day-to-day)
