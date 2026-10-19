# PRD 08: Compare page and launch kit

Status: shipped 2026-10-19; posting is the user's.

## Goal

People choosing a tool want to know how it differs from the ones they've heard of. And a launch needs copy ready to post. Both should be honest: say where others are ahead.

## Locked decisions

- `/compare` is a page with a table of the alternatives (usage trackers and account switchers) and what each does, every claim linked to its source and dated, and a short "when to pick something else" section.
- `docs/launch/` holds drafts the user posts: Show HN, r/ClaudeAI, X thread, Product Hunt listing, and a press kit list (name, one-liner, screenshots, film). Nothing is posted by us.
- `/press` isn't a page yet; the kit's assets are the site's own video and posters.

## Acceptance criteria

- WHEN someone opens `/compare` the system SHALL show every alternative with a link to it and the date the comparison was checked.
- WHEN the user opens `docs/launch/` they SHALL find a ready-to-paste post for each channel, each under that channel's length limits.

## Implementation notes

Shipped 2026-10-19.

- `/compare` is `apps/web/content/compare.md`: three tables (side by side, usage, switchers), what only Claude Notch does, where others are ahead, and when to pick something else. Before writing it, every link was fetched (all 200), each GitHub repo's licence and archived state read from the API, and the two paid tools' prices read from their pages ($20 and $14, once). Star counts were left out, as they go stale. Claims about Claude Notch itself (Carbon hotkeys without Accessibility, only the usage and profile endpoints) were checked in the Swift source.
- No tool's bug reports are cited on the page, only what each does.
- `docs/launch/`: Show HN, r/ClaudeAI, an X thread, Product Hunt and a press kit, with a README of what to do before posting. `node docs/launch/check.mjs` checks each against its channel's limits; all pass. Brackets mark the lines only the user can write.
- Open: screenshots for Product Hunt, taken on the day.
