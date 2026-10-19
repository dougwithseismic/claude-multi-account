# Show HN

## Title

Show HN: Claude Notch – Claude accounts side by side, with limits by the notch

## URL

https://dougwithseismic.github.io/claude-multi-account/

## Text

Leave the text box empty when posting a URL; post this as the first comment instead.

---

I have more than one Claude account: [personal and work, say, or one per client]. Switching used to mean signing out and back in as someone else. Claude Notch runs the Claude desktop app once per account, each with its own data folder, so they're all open and signed in at the same time, and it shows every copy's 5-hour and weekly limits beside the MacBook notch.

A few things that turned out to be fiddly:

- Sign-in. macOS hands every claude:// link to whichever copy started first, so signing in to the second copy signed in the first. Claude Notch owns the scheme and passes each link to the copy you used last.
- Reading usage without touching the login. Each copy encrypts its login with Electron's safeStorage. The app reads it read-only, keeps it in memory, never refreshes it (so it can't sign you out), and calls the same two endpoints Claude Code's /usage does: every 5 minutes, backing off when they're rate-limited.
- Teams. A login can belong to a personal plan and a Team at once; each organization gets its own row, with the one in use first.

Also: ⌥⌘1, 2, 3 bring a copy to the front (no Accessibility permission needed), the window in front gets an outline in its account's colour, and claude-usage prints the same numbers in a terminal.

It's Swift and SwiftUI, for macOS 26. There's no signed download yet, so it builds on your Mac:

    curl -fsSL https://dougwithseismic.github.io/claude-multi-account/install.sh | zsh

That runs a short script ([bootstrap.sh](https://github.com/dougwithseismic/claude-multi-account/blob/main/bootstrap.sh)) that clones the repo and runs install.sh, which takes no input and is safe to run again. It doesn't modify Claude.app, so Claude keeps updating normally.

The site also has guides to how the limits work, each citing Anthropic's own pages, and a pace calculator that works in any browser.

It's free; the source is on GitHub: https://github.com/dougwithseismic/claude-multi-account

Where others are ahead (a signed download, Claude Code accounts in the terminal, other tools like Codex) is on the compare page: https://dougwithseismic.github.io/claude-multi-account/compare/

I'd like to hear what breaks, and what you'd want it to show.
