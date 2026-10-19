---
title: Settings
description: Every switch on Claude Notch's settings page, and what each one does.
section: Using it
order: 5
---

Open the panel and click the **gear** at its top left. Settings are kept on your Mac only.

| Setting | What it does | Default |
| --- | --- | --- |
| **Show emails and team names** | Rows show each account's email and Team name instead of the profile's name. Holding <kbd>⌥</kbd> over the panel does the same for a moment | Off |
| **Open on** | **Hover**: rest the pointer on the notch. **Click**: only a click opens it, and a second click closes it | Hover |
| **Limit alerts** | A peek when the copy in use passes 90% of its 5-hour limit, runs out of a limit, or gets one back | On |
| **Switch peeks** | A peek naming the copy a <kbd>⌥⌘</kbd> hotkey switched to | On |
| **⌥⌘0 switches to the most room** | <kbd>⌥⌘0</kbd> switches to the copy with the most room, as in [Day to day](/docs/day-to-day). Off frees the key for another app | On |
| **Haptic feedback** | A tick on the trackpad as the panel opens by hover | On |
| **Open at login** | Starts Claude Notch with your Mac | On after the first run |

## Reading it

What the rings and bars mean, **Show the welcome page again** (the page the first run opens on), and links to [How limits work](/learn/how-limits-work) and [what's new](/changelog).

## Profiles

**Edit** opens `profiles.json`, which sets each copy's name, colour and hotkey. **Reload** applies your changes without restarting. See [Names, colours and keys](/docs/profiles).

## Quitting

Claude Notch has no Dock icon. Quit it from the bottom of the settings page. Your copies of Claude keep running; only the rings, hotkeys, outline and link routing stop until you open it again.

## For checking by eye

The app's binary takes a few options that are handy when something looks wrong:

```bash
~/claude-multi-account/apps/notch/build/"Claude Notch.app"/Contents/MacOS/ClaudeNotch --demo --pin
```

- `--demo` shows six made-up copies (A to F) in every state instead of yours. It reads nothing and keeps its settings apart from the app's.
- `--pin` keeps the panel open.
- `--no-notch` draws the pill used on screens without a notch.
- `--welcome` opens on the welcome page, as the first run does.
- `--snapshot <file.png>` renders the rings, the peeks, the open panel and its settings to a picture and quits; with `--welcome`, the welcome page too.
