# X thread

Attach the hero loop (`apps/web/public/video/notch-hero.mp4`) to the first post and the film (`notch-film.mp4`) to the third.

---

1/
I run more than one Claude account, and switching meant signing out and back in.

So now each one runs in its own copy of the Claude desktop app, all signed in at once, with every account's limits beside the MacBook notch.

Claude Notch, free for macOS 26:

---

2/
Rest the pointer on the notch: each copy's 5-hour and weekly limits, when they reset, and a tick showing whether you're ahead of an even pace.

Teams and personal plans each get their own row.

---

3/
⌥⌘1, 2, 3 bring a copy to the front. The window in front gets an outline in its account's colour, so you always know which one you're typing into.

---

4/
The fiddly part was sign-in: macOS sends every claude:// link to the copy that started first. Claude Notch passes it to the copy you're actually signing in to.

---

5/
It reads each copy's login read-only, never refreshes it, and only calls the usage check Claude Code's /usage makes.

One line to install:
curl -fsSL https://dougwithseismic.github.io/claude-multi-account/install.sh | zsh

---

6/
Guides to how Claude's limits work, each citing Anthropic's pages, and a pace calculator that works in any browser:

https://dougwithseismic.github.io/claude-multi-account/

Source: https://github.com/dougwithseismic/claude-multi-account
