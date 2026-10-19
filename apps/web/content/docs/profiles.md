---
title: Names, colours and keys
description: profiles.json sets each copy's label, colour and hotkey. Add a fourth copy, or a tenth, with one command.
section: Using it
order: 6
---

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

**Edit** under Profiles in Claude Notch's [settings](/docs/settings) opens the file, and **Reload** applies your changes. `claude-usage` reads it too. The [setup planner](/tools/setup) builds one for you.

> **Tip:** A label that is an email address is treated as private, like the emails from Anthropic: hidden until you show details.

## Add more copies

To go from three to four (A to D):

```bash
~/claude-multi-account/install.sh 4
```

It adds D to profiles.json (purple, <kbd>⌥⌘4</kbd>), makes its data folder and launcher, and restarts Claude Notch. Then open it with <kbd>⌥⌘4</kbd> and [sign in](/docs/sign-in). Its ring appears after its first start.

Any number up to 26 works. Copies after the ninth get no hotkey unless you give them a letter. Each copy is a full Claude app, so expect roughly 0.5 to 1 GB of memory per open copy.

An existing profiles.json is only ever added to: re-running the installer never changes a label, colour or key you've set.
