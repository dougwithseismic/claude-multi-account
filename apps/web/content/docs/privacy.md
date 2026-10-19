---
title: Privacy and security
description: What Claude Notch reads, what it sends, what it stores, and what it never touches.
section: Help
order: 9
---

Claude Notch reads each copy's login to check that account's usage. That's sensitive, so it follows strict rules.

## What it reads

- Each copy's data folder in `~/Library/Application Support`: its `config.json`, where Claude keeps its login encrypted, and its cookie database, to learn which organization the copy is working in. The cookie database is opened read only, so Claude's own writes are never blocked.
- The **Claude Safe Storage** key in your Keychain, once, with your permission. Every copy of Claude encrypts its login with that one key.
- `~/.config/claude-multi-account/profiles.json`, for names, colours and keys.

## What it sends

Only two requests, both to Anthropic, both the ones Claude Code's own `/usage` makes:

- `GET https://api.anthropic.com/api/oauth/usage` for each account's limits, at launch and then every 5 minutes, backing off when rate-limited.
- `GET https://api.anthropic.com/api/oauth/profile` for the account's email and plan, at most every 12 hours.

There's no analytics, no crash reporting, no update check and no server of ours. This website has no cookies or trackers either.

## What it never does

- **Never refreshes a login.** Refreshing rotates the login, which would leave the copy of Claude that owns it signed out. When a login has expired, the panel asks you to open that copy instead.
- **Never writes to Claude's files** or changes Claude.app. Claude stays signed by Anthropic and keeps updating as normal.
- **Never stores the key or a login.** Both stay in memory while the app runs, and are never written to disk or the log.
- **Never sends a message to Claude** or uses any of your limits to check them.

## On screen

Rows show the profile's name and plan, not the email or a Team's name, until you click the eye or hold <kbd>⌥</kbd>. So the panel can open during a screen share without showing who you are.

## Check it yourself

The source is [on GitHub](https://github.com/dougwithseismic/claude-multi-account). Reading the logins is all in `apps/notch/Sources/UsageCore`, and both network calls are in `UsageClient.swift`. The [app's design document](https://github.com/dougwithseismic/claude-multi-account/blob/main/docs/notch-prd.md) explains each choice.

> **Note:** Claude Notch is not made by Anthropic. It uses an endpoint Anthropic doesn't document, the same one Claude Code's `/usage` uses, so a change at Anthropic could stop the numbers until the app is updated. It shows "Usage unavailable" rather than numbers it isn't sure of.
