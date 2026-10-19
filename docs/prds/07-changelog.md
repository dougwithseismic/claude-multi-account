# PRD 07: Changelog and what's new

Status: shipped 2026-10-19.

## Goal

People who install from source need to know what changed when they pull, and visitors judge a project by whether it's alive. One changelog, kept in the repo, shown on the site and linked from the app.

## Locked decisions

- `CHANGELOG.md` at the root, newest first, one `## 0.5 — 2026-10-19` heading per release with **App**, **Command line**, **Site** and **Guides** groups. Unreleased work goes under `## Unreleased`.
- `/changelog` renders it with the docs plugin, each release with an anchor.
- The app's settings page links to it (PRD 05).
- The home page shows the latest release in its hero badge ("New in 0.5: …") linking to `/changelog`.

## Acceptance criteria

- WHEN a release heading is added to `CHANGELOG.md` the system SHALL show it on `/changelog` at the next deploy, with no other file to edit.
- WHEN someone opens `/changelog#0-5` the system SHALL scroll to that release.

## Implementation notes

`/changelog` shipped 2026-10-19: it renders `CHANGELOG.md` with the docs plugin, a file without frontmatter taking its title from `# Changelog`. Release headings are anchored by version (`## 0.5 — …` is `#0-5`). The hero badge and the app's link wait for 0.5 (PRD 05).

0.5, 2026-10-19: the hero badge reads "New in 0.5: pace, most room, status line" and links to `/changelog/#0-5`; it's `hero.badge` in `apps/web/src/content.ts`, changed by hand each release. "Free, for macOS 26", which the badge used to say, moved to the end of the hero's lead. The app's settings link to the changelog. 0.5's notes use the App, Command line, Site and Guides groups.
