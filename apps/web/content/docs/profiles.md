---
title: Names, colours and keys
description: Add, rename, recolour and remove copies in the Copies window, or in profiles.json. A fourth copy, or a tenth, is one click.
section: Using it
order: 6
---

## The Copies window

Open the panel, click the **gear**, then **Manage…** under Copies. Each copy has a row:

- Its **name**, as it shows in the panel and peeks, for example "Work" or "Client: Acme". Type to change it.
- How it's doing: signed in and on which plan, not signed in, or not opened yet. **Sign in** or **Open** beside it brings that copy to the front.
- Its **colour**, for the ring, badge and window outline.
- Its **key** after <kbd>⌥⌘</kbd>. A key another copy has isn't offered.
- The **bin**, to remove it.

Changes apply as you make them. Claude A is Claude itself, so it can't be removed.

## Add more copies

**Add Claude D** at the bottom of the window makes D's data folder and launcher, adds it to the list (purple, <kbd>⌥⌘4</kbd>) and puts its ring by the notch, dimmed until it's signed in. Then click **Sign in** beside it, or press <kbd>⌥⌘4</kbd>, and [sign in](/docs/sign-in).

Any number up to 26 works. Copies after the ninth get no hotkey unless you give them one. Each copy is a full Claude app, so expect roughly 0.5 to 1 GB of memory per open copy.

From Terminal, the installer does the same. To go from three copies to four (A to D):

```bash
~/claude-multi-account/install.sh 4
```

It adds D to profiles.json, makes its data folder and launcher, and restarts Claude Notch.

## Remove a copy

The bin beside it asks how:

- **Remove** takes away its ring, launcher and key. Its data folder stays, so if you add the same letter again it's still signed in, with its settings.
- **Remove and delete its data** deletes the data folder too, which signs it out. Quit that copy first.

## profiles.json

`~/.config/claude-multi-account/profiles.json` lists each copy with its letter, label, colour and hotkey. `install.sh` writes it the first time from the template in the repository:

```json
[
  { "letter": "A", "label": "Claude A", "color": "#2F7BF5", "hotkey": "1" },
  { "letter": "B", "label": "Claude B", "color": "#F5822F", "hotkey": "2" },
  { "letter": "C", "label": "Claude C", "color": "#2FB36B", "hotkey": "3" }
]
```

- **letter**: A is Claude's usual data folder; any other letter X uses `Claude-X`.
- **label**: the name in the panel and peeks, for example "Work" or "Client: Acme".
- **color**: the ring, badge and window outline, as a hex colour.
- **hotkey**: the key after <kbd>⌥⌘</kbd>, a digit or a letter. Leave it out for no hotkey.

The Copies window writes this file, and **Edit file** under Copies in [settings](/docs/settings) opens it. A save applies within a couple of seconds, without restarting, and a letter you add gets its data folder and launcher made. If the file has a mistake, the copies in use stay and settings says so until it's fixed. `claude-usage` reads it too. The [setup planner](/tools/setup) builds one for you.

> **Tip:** A label that is an email address is treated as private, like the emails from Anthropic: hidden until you show details.

An existing profiles.json is only ever added to: re-running the installer never changes a label, colour or key you've set.
