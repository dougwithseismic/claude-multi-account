---
title: Sign in to each copy
description: Allow Keychain access once, then sign in to B and C one at a time. Each copy stays signed in after that.
section: Start
order: 2
---

## Allow Keychain access

Claude Notch's first run asks for access to **Claude Safe Storage**. Enter your login password and click **Always Allow**.

Each copy of Claude encrypts its own login with that key, and Claude Notch reads the login to check that account's usage. It only reads: it never refreshes a login or writes to Claude's files. [Privacy and security](/docs/privacy) has the details.

> **Note:** The build is signed with your first code-signing certificate (or `CODESIGN_IDENTITY` if you set it), so later updates don't ask again. With no certificate it signs ad hoc, and macOS asks again after every update.

## Sign in to B and C

Do this once for each extra copy, one at a time:

1. Open it: <kbd>⌥⌘2</kbd> for B, <kbd>⌥⌘3</kbd> for C. Its window gets that copy's coloured outline.
2. Click **Sign in** and finish in the browser.
3. When the browser asks to open Claude, allow it. The login goes to the copy you opened.

The first time, macOS asks whether "Claude Notch" may control "Claude". Click **Allow**: that's how the sign-in link reaches the right copy.

> **Warning:** Don't click into another Claude between steps 2 and 3. Sign-in links go to the copy you used last, so that one would receive the login instead. The panel's footer says which copy links go to.

## Why this is needed

macOS sends every `claude://` link, the sign-in link included, to the copy of Claude that started first. On its own, signing in to B would sign A in again. Claude Notch takes those links and passes each one to the copy you used last. [How it works](/docs/how-it-works) explains the rest.

## After signing in

Each copy stays signed in. Claude's logins last about 30 days and each copy renews its own while it's open.

Optional: give the copies different themes (Settings → Appearance in each Claude), for example A in Light and B in Dark, so you can tell them apart at a glance.

Claude Notch adds itself to your login items on its first run, and macOS shows a notification saying so. Turn off **Open at login** in its [settings](/docs/settings) to stop that. The hotkeys, the outline and link routing need no Accessibility permission.
