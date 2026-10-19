# Decisions

Settled choices. Don't relitigate them; add new calls with their date.

## Product

- **What it is:** Claude Notch, a free Mac toolkit for people who use more than one Claude account. It runs the Claude desktop app once per account, switches between them, and shows every account's limits beside the notch. The repo is `dougwithseismic/claude-multi-account`.
- **Two pillars (2026-10-19, the user's call):**
  - **Education:** the clearest place on the web to learn how Claude's usage limits work and how to run several accounts. Docs for the app, guides on limits, and guidance inside the app itself.
  - **Tooling:** the Notch app, the `claude-usage` command, the Claude Code status line, the installer, and small web tools that work without installing anything.
- **Audience:** heavy Claude users on a Mac: people with a personal plan and a work Team, freelancers with client accounts, and Max users who run out mid-week.
- **Free, source on GitHub.** No licence yet (see the backlog), so the site says "free" and "source on GitHub", not "open source". No accounts, no payments, no telemetry. Privacy is part of the product: read only, nothing leaves the Mac except the two Anthropic calls `/usage` already makes.
- **Facts in guides** come from Anthropic's own pages or from measurements made in this repo. Every guide lists its sources and the date they were last checked. Numbers Anthropic doesn't publish aren't guessed.

## Site

- `apps/web`: TanStack Start, prerendered to static HTML, published to GitHub Pages at `https://dougwithseismic.github.io/claude-multi-account/` by `.github/workflows/pages.yml` on every push to `main` that touches the site.
- Long-form pages (docs and guides) are Markdown in `apps/web/content/`, compiled to HTML at build time by a small Vite plugin. No Markdown parser ships to the browser.
- Same look as the home page: black, Geist, one serif italic word per heading, the app's profile colours. Mockups of the app reuse `src/components/notch/`.
- No analytics, cookies or third-party scripts until the user decides otherwise.
- Internal links go through the router or are rewritten for the Pages base path at build time.

## App

- Swift 6.2, macOS 26, no third-party dependencies. See [notch-prd.md](notch-prd.md) for everything the app already does and why.
- Read only, never refresh a login, never write to Claude's files. Tokens never touch disk or logs.
- Anything the app shares with other tools (the CLI, the status line) is written without tokens, emails or organization names.
- Claude Code in the terminal gets a login per copy through `CLAUDE_CONFIG_DIR` (`claude-b` on `~/.claude-B`), set up by `install.sh --claude-code`. The installer only links into those folders and never replaces anything in them, and nothing of ours runs `claude` to check a login.

## Shipping

- **Deploying (2026-10-19, the user's call):** "recursively deploy". Work lands on a branch, goes up as a PR, and is merged to `main`, which publishes the site. One PR per wave of finished PRDs.
- Never post, announce or submit anywhere on the user's behalf. Launch copy is drafted in `docs/launch/` for the user to post.
- Spending money (domains, an Apple Developer ID) is the user's call.
- `CHANGELOG.md` at the root records every user-visible change, newest first, and the site's `/changelog` renders it.
- Commits: one feature each, plain factual messages, no co-author trailers (the user's global rule).

## Gates

- Site: `pnpm --filter @claude-notch/web typecheck`, `pnpm --filter @claude-notch/web build`, `pnpm check`.
- App: `swift test` in `apps/notch`, and `scripts/build-app.sh` builds and signs.
- Shell: `zsh -n` on every script touched.
