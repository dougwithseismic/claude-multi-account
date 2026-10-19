# Backlog

Ordered. `[ ]` not started, `[~]` shipped up to a seam, `[x]` done. Each PRD is in `docs/prds/`.

## Queue

| # | PRD | Pillar | Status |
| --- | --- | --- | --- |
| 01 | [The Notch app, milestones 1–4 and the UX revamp](notch-prd.md) | Tooling | [x] |
| 02 | [Docs on the site](prds/02-docs.md) | Education | [ ] |
| 03 | [Learn: guides to Claude's limits](prds/03-learn.md) | Education | [ ] |
| 04 | [Web tools: pace calculator and setup planner](prds/04-web-tools.md) | Tooling | [ ] |
| 05 | [Notch 0.5: pace, best account, status line, first run](prds/05-notch-05.md) | Both | [ ] |
| 06 | [One-line install and `--doctor`](prds/06-install.md) | Tooling | [ ] |
| 07 | [Changelog and what's new](prds/07-changelog.md) | Both | [ ] |
| 08 | [Compare page and launch kit](prds/08-launch.md) | Education | [ ] |

## Needs the user

Things only the user can do. Work continues around each one.

1. **Pick a licence.** The repo has none, so legally nobody may use or change the code. MIT matches the prior art the app borrows from. Until then the site says "source available" rather than "open source".
2. **Apple Developer ID** ($99 a year) to ship a signed, notarized download and a Homebrew cask, so people don't need Xcode's tools to install. Until then the installer builds from source.
3. **Post the launch.** Drafts for Show HN, Reddit, X and Product Hunt are in `docs/launch/` (PRD 08).
4. **Optional: a domain** (for example `claudenotch.app`). The site works on GitHub Pages without one.

## Parking lot

- Signed DMG, Homebrew cask and auto-update (needs the Developer ID above).
- Usage history: a sparkline per account and a week view, kept locally.
- Notifications through Notification Center as well as peeks.
- Raycast extension that reads the Notch's shared snapshot.
- Separate Claude Code logins per copy (`CLAUDE_CONFIG_DIR`), once how it stores logins is confirmed.
- Per-page social images for guides.
