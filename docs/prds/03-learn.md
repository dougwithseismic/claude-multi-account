# PRD 03: Learn, guides to Claude's limits

Status: not started.

## Goal

People search for how Claude's 5-hour and weekly limits work, what each plan gets, and how to run more than one account. The answers out there are scattered, often out of date, and rarely say where they came from. Learn is a set of guides that answer those questions clearly, cite Anthropic, and show the numbers the way the Notch draws them. It's the education pillar's front door and how most people will find the app.

## Locked decisions

- Markdown in `apps/web/content/learn/*.md`, same plugin as the docs. Frontmatter adds `checked` (the date the sources were last read) and `sources` (title and URL each).
- `/learn` is an index of guides as cards; `/learn/$slug` is one guide, with the sources and "Last checked" at the end.
- Facts come from Anthropic's pages or from what this repo measured (`notch-prd.md`). No made-up message counts. Where Anthropic gives only relative sizes ("5x Pro"), the guide says so.
- Interactive figures where they teach better than words: a ring and bars the reader can drag, using the app's own mockup components.
- Each guide ends with a short, honest pointer to the tool that helps (the Notch, the pace calculator, `claude-usage`), never a hard sell.

## Acceptance criteria

- WHEN someone opens `/learn` the system SHALL list every guide with its title, one-line summary and reading time.
- WHEN someone reads a guide the system SHALL show its sources with links and the date they were last checked.
- WHEN someone drags the figure in "Reading the rings" the system SHALL redraw the ring and bars as the app would, including red at 90% and the cross at a full weekly limit.
- WHEN a guide is shared the system SHALL give it its own title, description and image in the link preview.

## Guides (first wave)

1. How Claude's usage limits work: the 5-hour window, weekly limits, model-specific limits, what resets them.
2. Plans and their limits: Free, Pro, Max 5x, Max 20x, Team, Enterprise, and extra usage, in Anthropic's own terms.
3. Pacing: reading the pace tick, and how to tell whether you'll run out before the reset.
4. Running more than one Claude account on a Mac: the options (sign out and in, browser profiles, separate copies) and their trade-offs.
5. Teams and organizations: one login, several organizations, which limits apply.
6. Claude Code and your limits: `/usage`, the status line, sharing limits with the app.
7. Reading the rings: an interactive guide to the Notch's rings, bars and tick.

## Tasks

1. Learn index and guide routes, guide layout with sources.
2. The interactive ring figure.
3. Write the guides from the research (sources in each).
4. Link Learn from the nav, footer and home page.

## Implementation notes

(Filled in after shipping.)
