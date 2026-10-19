# Backlog

Ordered. `[ ]` not started, `[~]` shipped up to a seam, `[x]` done. Each PRD is in `docs/prds/`.

## Queue

| # | PRD | Pillar | Status |
| --- | --- | --- | --- |
| 01 | [The Notch app, milestones 1–4 and the UX revamp](notch-prd.md) | Tooling | [x] |
| 02 | [Docs on the site](prds/02-docs.md) | Education | [x] |
| 03 | [Learn: guides to Claude's limits](prds/03-learn.md) | Education | [x] |
| 04 | [Web tools: pace calculator and setup planner](prds/04-web-tools.md) | Tooling | [x] |
| 05 | [Notch 0.5: pace, best account, status line, first run](prds/05-notch-05.md) | Both | [x] |
| 06 | [One-line install and `--doctor`](prds/06-install.md) | Tooling | [x] |
| 07 | [Changelog and what's new](prds/07-changelog.md) | Both | [x] |
| 08 | [Compare page and launch kit](prds/08-launch.md) | Education | [x] |
| 09 | [Claude Code in the terminal, one login per copy](prds/09-claude-code.md) | Tooling | [x] |

## Needs the user

Things only the user can do. Work continues around each one.

1. **Pick a licence.** The repo has none, so legally nobody may use or change the code. MIT matches the prior art the app borrows from. Until then the site says "free" and "source on GitHub", never "open source".
2. **Apple Developer ID** ($99 a year) to ship a signed, notarized download and a Homebrew cask, so people don't need Xcode's tools to install. Until then the installer builds from source.
3. **Post the launch.** Drafts for Show HN, Reddit, X and Product Hunt are ready in `docs/launch/`, with a checklist in its README. Fill the `[…]` lines, which only you can write.
4. **Optional: a domain** (for example `claudenotch.app`). The site works on GitHub Pages without one.
5. **A legal read before a loud launch.** Two things in Anthropic's own pages, quoted in `docs/research/2026-10-19-claude-limits.md` under Terms:
   - Claude Code's legal page says developers may not collect, store or intermediate Claude.ai credentials or session tokens. The Notch reads each copy's stored login on the Mac, keeps it in memory only, and calls only the usage and profile endpoints, as CodexBar, openusage and others do. Whether that's acceptable to distribute is the user's judgement.
   - The Usage Policy taking effect on 2026-11-12 widens its wording on multiple accounts (in the context of avoiding detection and guardrails). The site's manifesto talks about switching accounts "every time a limit ran out". Guides written in this wave frame several accounts as personal and work, or client, accounts, and don't suggest using accounts to get more usage. Whether to change the home page's wording is the user's call.

## Parking lot

- Signed DMG, Homebrew cask and auto-update (needs the Developer ID above).
- Usage history: a sparkline per account and a week view, kept locally.
- Notifications through Notification Center as well as peeks.
- Raycast extension that reads the Notch's shared snapshot.
- Per-page social images for guides.
