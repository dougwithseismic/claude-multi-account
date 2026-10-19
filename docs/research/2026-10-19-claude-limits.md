# Claude's limits, Claude Code and multiple accounts: sourced facts

Checked 2026-10-19. **[official]** is an Anthropic domain (support.claude.com, claude.com, code.claude.com, anthropic.com); **[third-party]** is anything else; **[unconfirmed]** couldn't be verified. Guides in `apps/web/content/learn/` cite from here; re-check a source before relying on it after a few weeks.

## Plan usage limits

- **[official]** Paid plans have a session limit that resets every five hours and weekly limits that reset once a week. claude.ai, Claude Code and Claude Desktop all count against the same limit. https://support.claude.com/en/articles/11647753-how-do-usage-and-length-limits-work
- **[official]** The pricing FAQ: every plan's limits reset on a "rolling" five-hour window; paid plans add weekly limits; web, desktop, mobile and Claude Code draw from one pool. https://claude.com/pricing
- **[unconfirmed]** When the 5-hour window starts on consumer plans. The old "About Claude's Max plan usage" article (11014257), which guides cite for "starts at your first message", now returns 404.
- **[official, Claude for Government only]** The window has no timer until the first message; resets land on the top of an hour. Fits what the Notch measured (an unstarted window has no reset time), but don't state it for consumer plans. https://claude.com/docs/government/account/usage
- **[official]** Weekly limits reset at a fixed day and time assigned to the account, independent of when you start using Claude or subscribed, shown in Settings > Usage. Same in the Pro, Max and Team articles: https://support.claude.com/en/articles/8325606-what-is-the-pro-plan, https://support.claude.com/en/articles/11049741-what-is-the-max-plan, https://support.claude.com/en/articles/9266767-what-is-the-team-plan
- **[official]** Max plans have a separate weekly limit for Fable. https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan
- **[official]** Fable by plan (article dated 2026-09-02): on Max, Team premium seats and legacy seat-based Enterprise premium seats, up to 50% of weekly limits can go to Fable at no extra cost, and Fable uses limits faster. On Pro and Team standard seats, Fable runs only on usage credits. https://support.claude.com/en/articles/15424964-claude-fable-models-on-your-plan
- **[unconfirmed]** Separate Opus or Sonnet weekly limits today. No current official page mentions a per-model weekly limit other than Fable. (The usage endpoint still has `seven_day_opus` and `seven_day_sonnet` fields, usually null.)

### Plans, in Anthropic's relative terms [official]

- **Free:** a session limit that resets every five hours; message counts vary with demand. No weekly limit mentioned. https://support.claude.com/en/articles/8114491-getting-started-with-claude
- **Pro:** at least 5x Free's usage per 5-hour session (pricing FAQ), plus a weekly limit across all models (Pro article).
- **Max 5x / 20x:** 5x or 20x Pro's per-session allowance, plus a weekly limit across all models; $100 / $200 a month (Max article).
- **Team:** standard seats get 1.25x Pro's per-session allowance and premium seats 6.25x. Each seat type has a weekly limit across all models; limits are per member (Team article). The pricing page puts premium at 5x standard.
  - **Discrepancy:** the Notch measured a Team seat with no all-models weekly window, but the help centre says Team seats have one.
- **Enterprise:** usage-based plans have no plan- or seat-level limits and bill at API rates. Legacy seat-based Standard/Premium plans keep per-seat limits until renewal. https://support.claude.com/en/articles/9797531-what-is-the-enterprise-plan
- **All plans:** Anthropic may add other caps (weekly, monthly, by model or feature) at its discretion (Pro and Max articles, pricing FAQ).

### Extra usage, now "usage credits" [official]

- At the 5-hour, weekly or Fable weekly limit, requests can switch to pay-as-you-go at standard API rates. Set up in Settings > Usage: prepay with "Add funds", a monthly spend limit (or unlimited), optional auto-reload. Max's included monthly API credits can't pay for it. https://support.claude.com/en/articles/12429409-manage-usage-credits-for-paid-claude-plans
- On Team and seat-based Enterprise the organization turns it on. https://support.claude.com/en/articles/12005970

### Other [official]

- **Limit resets** are given occasionally: a "Reset for free" button refills the 5-hour or weekly limit, on web or Desktop only. https://support.claude.com/en/articles/17007452-what-is-a-limit-reset
- **Claude Code Wrap-Up Allowance:** a small, capped allowance that lets a response in progress finish at the 5-hour limit; on Pro at most once per weekly period; rolling out gradually. https://support.claude.com/en/articles/17040437-claude-code-wrap-up-allowance
- **What uses limits faster:** message length, attachment size, conversation length, tools (Research, web search), model, effort level, artifacts and multi-step tasks. https://support.claude.com/en/articles/9797557-usage-limit-best-practices. Long chats that trigger automatic context management use more; tools and connectors are token-heavy; turning extended thinking off is advised (11647753). In Claude Code, Opus uses meaningfully more. https://support.claude.com/en/articles/14552983-models-usage-and-limits-in-claude-code
- **Peak hours:** on 2026-05-06 Anthropic removed the peak-hours reduction on Claude Code for Pro and Max, and doubled Claude Code's 5-hour limits for Pro, Max, Team and seat-based Enterprise. https://www.anthropic.com/news/higher-limits-spacex
  - **[third-party]** The original reduction (late March 2026) was weekdays 5–11am PT, on Free, Pro and Max 5-hour limits; weekly limits unchanged. https://www.techradar.com/ai-platforms-assistants/claude/claude-is-limiting-usage-more-aggressively-during-peak-hours-heres-what-changed
  - **[unconfirmed]** Whether any peak-hours reduction still applies to claude.ai, Desktop or Free.
  - **[official]** Max and Team list priority access at high-traffic times (pricing page).

## Claude Code status line [official]

Docs: https://code.claude.com/docs/en/statusline

- Setting: `"statusLine": {"type": "command", "command": "...", "padding": 2}` in user or project settings; `refreshInterval` (seconds, minimum 1) re-runs on a timer too; `hideVimModeIndicator`.
- Runs at session start or resume, on each assistant message, after `/compact`, on permission or vim mode changes, when the command changes, each `refreshInterval`, and when a rate-limit window reaches `resets_at`. Debounced at 300 ms; a new run cancels one still running.
- Each stdout line is a row; ANSI colours and OSC 8 links work. Width from `COLUMNS`/`LINES` (`tput cols` doesn't work). Shown only after exit 0. Uses no API tokens.
- Stdin JSON includes `model`, `cwd`, `workspace.*`, `cost.*`, `context_window.*`, `session_id`, `version`, and **`rate_limits.five_hour` / `rate_limits.seven_day`**, each with `used_percentage` (0–100) and `resets_at` (Unix seconds), plus `rate_limits.spend_limit.*`.
- `rate_limits` appears only for Pro and Max subscribers (or behind a gateway with a spend limit) and only after the first API response; either window can be missing, and one is dropped once its `resets_at` passes. No per-model window is documented.

## Claude Code and multiple accounts

- **[official]** `CLAUDE_CONFIG_DIR` overrides `~/.claude` (settings, history, plugins), and the docs say it's useful for running several accounts side by side. Ignored in project and local settings. https://code.claude.com/docs/en/env-vars
- **[official]** To stay signed in to several accounts, give each its own config directory; each keeps its own settings, history and claude.ai login. The docs give an alias example, `claude-work`. Console sign-ins without an API key aren't kept apart. https://code.claude.com/docs/en/authentication
- **[official]** On macOS the login is in the Keychain, falling back to `~/.claude/.credentials.json` (0600). With `CLAUDE_CONFIG_DIR` set, the Keychain entry is keyed to that directory. The service name isn't documented.
- **[third-party]** Observed service names: `Claude Code-credentials` and `Claude Code-credentials-<8 hex>`. https://github.com/anthropics/claude-code/issues/90527. What the suffix is computed from is **[unconfirmed]**.
- **[third-party]** The Claude Code bundled in Desktop overwrites the CLI's `Claude Code-credentials` item (filed 2026-10-14). https://github.com/anthropics/claude-code/issues/101990
- **[official]** Commands (https://code.claude.com/docs/en/commands): `/login`, `/logout` (removes all stored credentials, including MCP logins), `/status` (account, model, connectivity), `/usage` (aliases `/cost`, `/stats`: plan-limit bars, session cost, activity; shows the last bars from the past hour if the usage check is rate limited; https://code.claude.com/docs/en/costs), `/usage-credits`, `/rate-limit-options`.

## Several accounts in the desktop app

- **[official]** The account menu switches only between a personal account and a Team or Enterprise account on the same email. https://support.claude.com/en/articles/13189465-log-in-to-your-claude-account. Each has its own conversations and projects. https://support.claude.com/en/articles/9267400
- **[official]** One person can belong to several Team or Enterprise organizations. https://support.claude.com/en/articles/13566435-find-and-join-a-team-or-enterprise-organization
- **Not found:** any official way to be signed in to accounts on different emails at once.
- **[third-party]** Requests for it: https://github.com/anthropics/claude-code/issues/18435 (open since January, ~900 👍); #36821 closed "not planned".

## Terms

- **[official]** Consumer Terms (effective 2025-10-08): don't share your login or make your account available to anyone else; work-domain accounts may be linked to the employer's organization; no automated or non-human access except by API key or where permitted. https://www.anthropic.com/legal/consumer-terms
- **[official]** Usage Policy in force (2025-09-15) prohibits coordinating malicious activity across multiple accounts to avoid detection or get around guardrails, and using another account to get around a ban. The next version (effective 2026-11-12) broadens the multiple-accounts wording. https://www.anthropic.com/legal/aup
- **[official]** Each Team seat belongs to one named person; members can't route work through another member's account to use their remaining usage. https://support.claude.com/en/articles/12004354-purchase-and-manage-seats-on-team-plans
- **Not found:** official text that explicitly allows or forbids one person holding several paid accounts (say a personal Max and a work Team). The help centre describes keeping a personal and an organization account on one email.
- **[official]** Subscription OAuth is meant for ordinary use of Claude Code and Anthropic's apps; developers may not collect, store or intermediate Claude.ai credentials or session tokens. https://code.claude.com/docs/en/legal-and-compliance
