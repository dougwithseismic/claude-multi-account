# Competitive landscape

Checked 2026-10-19 (stars and last push from the GitHub API that day; Reddit couldn't be reached). The compare page (PRD 08) is built from this; re-check before publishing a claim about another tool.

**The PRD's "Prior art" line is out of date.** Brow already shows every account's limits in the notch, and ModelDeck, Codenotch, Claude-Usage-Tracker and openusage show several accounts. What only Claude Notch does is narrower: several copies of the Claude desktop app side by side, with live limits for each copy and its organizations.

## Tools

Install key: N = signed and notarized download, Brew = Homebrew.

| Tool | Category | Multi-account | Live limits | Install | Price, licence | Stars |
| --- | --- | --- | --- | --- | --- | --- |
| [CodexBar](https://github.com/steipete/CodexBar) | Menu bar, many providers | Yes (Claude Code accounts) | Yes | Brew, zip | Free, MIT | 22.7k |
| [ccusage](https://github.com/ccusage/ccusage) | CLI | No | No: tokens and cost from local logs | npx | Free | 19.1k |
| [openusage](https://github.com/robinebers/openusage) | Menu bar | Per account/org, but reads only the default Desktop folder | Yes | N DMG, Brew, Sparkle | Free, MIT | 4.4k |
| [Claude-Usage-Tracker](https://github.com/hamed-elfayome/Claude-Usage-Tracker) | Menu bar, notch HUD (beta) | Yes: profiles, `claude-<profile>` launchers, auto-switch | Yes | N zip, Brew | Free, MIT | 3.7k |
| [token-monitor](https://github.com/Javis603/token-monitor) | Desktop widget | Yes | Limits and logs | N DMG, Brew; Windows, Linux | Free, MIT | 3.2k |
| [Codenotch](https://github.com/vinzdg/codenotch) | Notch-style pin | Yes, a ring per `~/.claude-<slug>` | Yes | N DMG; Windows | Free, MIT | 2.9k |
| [ClaudeBar](https://github.com/tddworks/ClaudeBar) | Menu bar | Claude unverified | Yes | N DMG, Brew | Free, Apache-2.0 | 1.6k |
| [TokenEater](https://github.com/AThevon/TokenEater) | Menu bar, widgets | No (unverified) | Yes | N DMG, Brew | Free, MIT | 516 |
| [Usage4Claude](https://github.com/f-is-h/Usage4Claude) | Menu bar | Accounts and orgs, via browser sign-in or session key | Yes | DMG, not notarized | Free, MIT | 409 |
| [Brow](https://github.com/efim0v/brow) | Notch | Every Claude Code account | Yes | Brew, zip (ad hoc) | Free, GPL-3.0 | 57 |
| [ModelDeck](https://github.com/timharris707/modeldeck) | Menu bar and daemon | Claude Code and Codex | Yes | DMG | PolyForm Noncommercial | 116 |
| [claude-swap](https://github.com/realiti4/claude-swap) | CLI switcher | Swap or parallel, rotates on limits | Dashboard | uv, pipx | Free, MIT | 3.7k |
| [CCS](https://github.com/kaitranntt/ccs) | CLI, OAuth proxy | Yes | Cost analytics | npm | Free, MIT | 2.9k |
| [clauth](https://github.com/uwuclxdy/clauth) | TUI switcher | Yes, auto-switch | Yes | cargo | Free, MIT | 248 |
| [claude-multiprofile](https://github.com/jmdarre-v/claude-multiprofile) | Desktop and Code launchers | Side by side, tinted Dock icons | No | npm | Free, MIT | 114 |
| [Claude Profiles](https://github.com/jyito/Claude-Profiles) | Desktop launchers, dashboard | Side by side; ⌘⌥1–9 only while its dashboard is open | No | N DMG, Brew | Free, Apache-2.0 | 10 |
| [claude-fix](https://github.com/sarhej/claude-fix) | Desktop launcher script | Side by side | No | Brew formula | Free, MIT | 11 |
| [Lanes](https://lanes.synthetixis.com/) | Desktop, menu bar | Side by side | No | DMG, not notarized | Free | n/a |
| [Claude Account Switcher](https://github.com/SnlperStripes/claude-account-switcher) | Desktop, tray | Swaps one Desktop between accounts | Every saved account | Raw binary | Free, Apache-2.0 | 10 |
| [Multi-Claude](https://multiclaude.app) | Desktop | Side by side, letter in the menu bar | No | Paid download | $20 | Closed |
| [DeckSpace Claude Accounts](https://deckspace.dev/claude-accounts/) | Desktop: Mac, Windows, Linux | Side by side, routes SSO sign-ins to the right window | No | Download | $14 | Closed |

## Where Claude Notch wins

1. **Live limits for side-by-side desktop copies.** The side-by-side tools (claude-multiprofile, Claude Profiles, Lanes, Multi-Claude, DeckSpace) show no usage; the tools that show desktop usage swap one account in and out of a single copy; openusage only reads the default folder.
2. **Demand Anthropic hasn't met.** [anthropics/claude-code#18435](https://github.com/anthropics/claude-code/issues/18435), open since January, ~900 👍 and 200 comments: switching must not stop work running under the other account. Swap tools can't do that; side-by-side copies can.
3. **Sign-in links reach the right copy.** Claude Profiles says to use the copy-code fallback; Multi-Claude suggests a private browser window; claude-multiprofile's Google sign-in doesn't complete (#24). Only DeckSpace (paid) routes sign-ins.
4. **Telling copies apart.** Nobody else draws an outline round the window in the account's colour, or has global hotkeys without Accessibility permission.
5. **Never refreshes a login**, so it can't sign anyone out. Brow's fallback refresh spends a little of the limit; Claude-Usage-Tracker has had token-rotation bugs (#239, #331, #263).
6. **Teams and organizations.** Claude-Usage-Tracker shows the organization's extra-usage total on Team plans (#325); openusage can't reach a second Claude home's login (#1214). Per-organization rows with "not in use" are a real edge.

## Where others are ahead

1. **Installing:** we need `git clone`, the command line tools and a build; no release, DMG, cask or notarization. Most rivals ship a notarized DMG and a cask, many with Sparkle updates.
2. **No licence:** "open source" isn't true yet.
3. **macOS 26+ only** (Claude Profiles runs on 14+, Lanes 13+, Multi-Claude 12+; Brow and Codenotch need 26 too).
4. **Claude Code CLI accounts:** every copy shares `~/.claude`; Brow, ModelDeck, Codenotch, Claude-Usage-Tracker and claude-multiprofile handle `CLAUDE_CONFIG_DIR` accounts.
5. **Other providers and platforms** (Codex, Cursor; Windows).
6. **Automatic switching** before a limit (claude-swap, clauth, Claude-Usage-Tracker).
7. **Memory:** 0.5–1 GB per Electron copy; swap tools cost nothing.
8. **Biggest threats:** Claude-Usage-Tracker (profiles, notch HUD, cask) could add desktop data folders; Brow already does the notch for every account.

## Content landscape

| Query | Who ranks | Gap |
| --- | --- | --- |
| claude usage limits explained | DataCamp, chudi.dev, claude-monitor.com, InventiveHQ, Verdent, wmedia.es | None cover several accounts, Team organizations or peak hours |
| claude 5 hour limit | fast.io, usagebar.com, claude.com gov docs | They disagree on whether resets land on the hour |
| claude weekly limit | implicator.ai, usagebar.com, Substack | Some still say rolling 7 days; Anthropic says a fixed time per account |
| multiple claude accounts | GitHub READMEs, ToolRadar, DeckSpace, melkon.tech, philippstracker.com, agentsroom.dev | Nobody covers limits per account; some copy the whole app, which stops it updating |
| claude max vs pro limits | zenken, dupple, IntuitionLabs, BenchLM | They contradict each other on per-model weekly caps |
| claude code status line usage | wmedia.es, ohugonnot, claudeissues.com | Some are out of date: the docs now include `rate_limits` |

Most ranking pages market a tool. What nobody covers well, and we know first-hand: limits across several accounts and organizations; why the `claude://` sign-in goes to the wrong copy; the fixed weekly reset per account; what the 2026 peak-hours and Claude Code changes mean.
