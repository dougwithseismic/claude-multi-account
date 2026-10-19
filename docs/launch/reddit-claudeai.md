# r/ClaudeAI

Flair: the one for things you built (check the current list). Say it's yours, and that it's free.

## Title

I built a free Mac app that runs each of my Claude accounts in its own copy of the desktop app, and shows every account's 5-hour and weekly limits beside the notch

## Body

I have [a personal account and a work Team account / an account per client], and switching between them in the desktop app meant signing out and back in every time. So I made each account its own copy of Claude:

- **Every account open at once.** Each copy has its own data folder, so A, B and C stay signed in side by side. ⌥⌘1, 2 and 3 bring one to the front.
- **Every limit in one place.** Rest the pointer on the notch and the panel shows each copy's 5-hour and weekly limits, with when they reset and a tick for an even pace. Team and personal organizations each get a row.
- **Sign-in goes to the right copy.** Normally macOS sends the sign-in link to the copy that started first. Claude Notch passes it to the one you're signing in to.
- **It doesn't touch your login.** It reads each copy's stored login on your Mac, never refreshes it, and only makes the same usage check Claude Code's /usage makes, every 5 minutes.

Install (macOS 26, builds on your Mac in a couple of minutes):

```
curl -fsSL https://dougwithseismic.github.io/claude-multi-account/install.sh | zsh
```

Site: https://dougwithseismic.github.io/claude-multi-account/
Source: https://github.com/dougwithseismic/claude-multi-account

There are also some guides that might help even if you don't use the app: how the 5-hour and weekly limits work, what each plan gets (with Anthropic's pages as sources), and a pace calculator for "will this last until it resets?".

It's macOS 26 only, and there's no signed download yet. Happy to answer questions, and I'd like to know what you'd want it to do next.
