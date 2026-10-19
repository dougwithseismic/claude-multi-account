# PRD 02: Docs on the site

Status: not started.

## Goal

Today every "Install", "Sign in" and "Uninstall" link on the site leaves for the README on GitHub, and the home page is the only page. A person who lands on the site should be able to install, sign in, understand every part of the panel and fix a problem without leaving it. This is the base the guides (PRD 03), tools (PRD 04) and changelog (PRD 07) build on.

## Locked decisions

- Pages are Markdown in `apps/web/content/docs/*.md` with frontmatter (`title`, `description`, `order`, `section`). A Vite plugin compiles each to `{ meta, html, toc }` at build time with `marked`; headings get ids, internal links get the base path. Nothing parses Markdown in the browser.
- One route per page, `/docs/$slug`, plus `/docs` (the first page's content and an index). Each is prerendered.
- Layout: the site's nav and footer, a left sidebar of every page grouped by section, the article (max 720px), and "On this page" on the right from wide screens. On phones the sidebar becomes a menu at the top.
- Command blocks have a copy button. Callouts are blockquotes that start with **Note**, **Tip** or **Warning**.
- The README stays the source for people on GitHub; the docs are the friendlier long form. Both say the same things.
- Every page has its own `<title>`, description, canonical URL and Open Graph tags. The site gets `sitemap.xml`, `robots.txt` and a default social image.

## Acceptance criteria

- WHEN someone opens `/docs/install` the system SHALL show the requirements, the install commands with copy buttons, and what the script does, without linking off-site to finish.
- WHEN someone clicks "Install" anywhere on the home page the system SHALL take them to `/docs/install`.
- WHEN a docs page loads the system SHALL highlight it in the sidebar and list its `##` headings under "On this page".
- WHEN someone clicks a copy button the system SHALL copy the command, without the prompt, and say "Copied" for a moment.
- WHEN the site is built the system SHALL prerender every docs page to its own HTML file, and `sitemap.xml` SHALL list them.
- WHEN a docs page is shared the system SHALL give it its own title, description and image in the link preview.
- WHEN JavaScript is off the system SHALL still show every docs page in full.

## Pages

| Section | Page | From |
| --- | --- | --- |
| Start | Install | README Install |
| Start | Sign in to each copy | README Allow Keychain access, Sign in to B and C |
| Using it | Day to day | README Day to day |
| Using it | Reading the panel | README What Claude Notch shows, the PRD's states table |
| Using it | Settings | README, the settings page |
| Using it | Names, colours and keys | README Names, colours and keys, Add more copies |
| Using it | `claude-usage` | README `claude-usage` |
| Help | Troubleshooting | New: every state the panel can show and what to do, plus install failures |
| Help | Privacy and security | PRD Risks and the read-only rules |
| Help | How it works | README How it works |
| Help | Updating and uninstalling | README Updates, Uninstall, Moving from Hammerspoon |

## Tasks

1. Markdown plugin and content loader (`apps/web/plugins/markdown.ts`, `src/content/docs.ts`).
2. Docs layout, sidebar, table of contents, copy buttons, callouts, prose styles.
3. Write the pages.
4. Point the home page's links at the docs; add Docs to the nav and footer.
5. Per-page head tags, `sitemap.xml`, `robots.txt`, social image.

## Implementation notes

(Filled in after shipping.)
