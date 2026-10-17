# PRD: Claude usage in the notch

Status: milestones 1–4 built, 2026-10-17 (`notch/`: UsageCore, the `claude-usage` CLI and the `ClaudeNotch` app, installed to `~/Applications`). The app also took over what Hammerspoon and the link router did (hotkeys, window outline, `claude://` links), and both are retired. It shows each organization a login belongs to, so a Team beside a personal plan is handled. Sleep, display changes, full screen and a lid-shut external display still need checking on the machine; see [What milestones 3 and 4 built](#what-milestones-3-and-4-built).

## Problem

I run three Claude accounts side by side (Claude A, B and C; see the [README](../README.md)). Each has a 5-hour limit and weekly limits, and I switch accounts when one runs out. Today the only way to see an account's limits is to open that copy of Claude and go to Settings → Usage, one account at a time. I find out an account is spent when it stops answering.

## What we're building

A small native Mac app that sits at the MacBook notch and shows every account's limits at a glance:

- **Collapsed (the default):** one small double ring per account beside the notch, in the account's colour (A blue, B orange, C green). The outer ring fills to that account's 5-hour use, the inner one to its fullest weekly window.
- **Hover the notch:** a panel drops down with one row per account: the account's email, the 5-hour bar with "resets in 2h 10m", the weekly bar with its reset, and any per-model weekly bars (for example Fable).
- **Click a row:** switches to that Claude, using the existing launchers.
- **And what Hammerspoon did:** ⌥⌘1/2/3 to switch, a coloured outline round the Claude window in front, and `claude://` links (sign-in among them) sent to the copy used last.

### Goals

1. See, without opening anything, which accounts have room left right now and when each one resets.
2. Pick the best account to work in and get to it in one click.
3. Never interfere with the Claude apps: read only, never sign anything out.

### Non-goals

- Token or cost accounting per session (phuryn/claude-usage and ccusage already do that).
- Codex, Gemini or other providers.
- Notifications in the first version (an optional "B is back under 50%" alert is in Later).
- Windows or Linux.
- Distribution to other people. This is for this Mac; if it's ever shared, the open questions on signing and licensing come back.

## How it gets the numbers

The research behind this is summarised under [Prior art](#prior-art). Every claim below was read in at least two projects' source code.

### Where each account's login comes from

Each copy of Claude keeps its own login in its data folder's `config.json`, under `oauth:tokenCacheV2`, encrypted with Electron's safeStorage. The app reads it in four steps, read only:

1. **Find the profiles:** `~/Library/Application Support/Claude` is A, and every `Claude-<letter>` folder beside it is that letter. All three exist and are signed in to different accounts (`lastKnownAccountUuid` differs).
2. **Get the key:** read the Keychain item service "Claude Safe Storage", account "Claude Key" (one prompt; choose Always Allow). Derive the key with PBKDF2-HMAC-SHA1, salt `saltysalt`, 1003 iterations, 16 bytes. All three copies share this one item, because Electron names it after the app, not the data folder. Keep the key in memory only; don't write it to disk.
3. **Decrypt** `oauth:tokenCacheV2`: base64-decode, strip the `v10` prefix, AES-128-CBC with a 16-space IV and PKCS7 padding. The result is JSON: a map from `"<clientId>:<orgUuid>:https://api.anthropic.com:<scopes>"` to `{ token, refreshToken, expiresAt (ms), subscriptionType?, rateLimitTier? }`. Some keys are written `acct:<userUuid>|<key>`.
4. **Pick an entry per organization**, using openusage's rules within each: drop entries whose user UUID doesn't match `lastKnownAccountUuid`, require the `user:profile` scope, prefer entries that also carry `user:inference`, then more scopes, then the latest `expiresAt`. (Ranking across all organizations at once, as openusage does, picks the wrong one for a Team member; see below.)

Use `oauth:tokenCacheV2` only: signing in moves the live token there and empties V1. The app never reads, decodes or uses `refreshToken` (see [Refreshing](#refreshing-never)).

### Teams and several organizations

One login can belong to several organizations, each with its own limits and its own token in the cache (the `<orgUuid>` in the key). On this Mac, B is in a personal Max 20x organization and a Team, and works in the Team. C is in the same Team and a free personal organization. So:

- **Every organization with a token is shown**, grouped under its copy. The row's header is the one the copy is working in; the others sit under it, marked "not in use".
- **Which one is in use** comes from the `lastActiveOrg` cookie for `claude.ai`, which Claude sets when you pick an organization in its account menu. The cookie is in the copy's Chromium cookie database (`Cookies` or `Network/Cookies`), encrypted like the login (`v10`, same key; newer Chromium puts a SHA-256 of the host before the value). The database is opened read only and immutable, so Claude's own writes are never blocked. Failing that: the organization of the newest sample in Claude's `plan-usage-history.json`, then the best-ranked login.
- **The cookie names an organization with no token** (picked, but never used in that copy): the row says "No login for this organization yet".
- **A free personal organization** gets no OAuth token from Claude, so it has nothing to show and isn't listed.
- **Renewing:** Claude renews only the token of the organization it's working in, so an expired token for another one says "Switch Claude B to this organization to update".
- **Leftovers:** a token whose `/api/oauth/profile` names a different account than the copy's `lastKnownAccountUuid` is from an earlier sign-in and is dropped.
- **Plan names** come from `/api/oauth/profile`'s `organization_type` and `rate_limit_tier` ("Team · Acme", "Max 20x · Personal"). A plan whose usage call returns every window null (some Team and Enterprise plans) says "No usage limits on this plan" rather than "Usage unavailable".

Before this, B's ring showed its personal Max organization (weekly limit at 100%, a red cross) while B was working in the Team with room left.

### The usage call

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer sk-ant-oat01-…
anthropic-beta: oauth-2025-04-20
```

This is the call Claude Code's `/usage` makes, and it returns what Claude's own usage card shows:

| Field | Meaning |
| --- | --- |
| `five_hour.utilization`, `.resets_at` | 5-hour window, 0–100, ISO-8601 UTC (sometimes with microseconds, sometimes null) |
| `seven_day.*` | Weekly, all models |
| `limits[]` with `kind: "weekly_scoped"` | Per-model weekly limits, named by `scope.model.display_name` (for example "Fable"); read these first |
| `seven_day_opus`, `seven_day_sonnet` | Older per-model fields, now often null; fall back to them |
| `extra_usage` | `is_enabled`, `monthly_limit`, `used_credits` (in cents), `utilization`, `currency` |

`GET https://api.anthropic.com/api/oauth/profile` with the same token returns the account's email and organization (`name`, `organization_type`, `rate_limit_tier`), which become the row labels. That also answers the earlier wish to see which account is which. It's cached for 12 hours per copy and organization.

Decode leniently: unknown fields are ignored and a missing window just isn't shown, because the endpoint is undocumented and gains fields over time.

### Refreshing: never

Refreshing a token rotates its refresh token, so the Claude copy that owns it is left holding a dead one and gets signed out. Every serious project avoids this: openusage won't even decode the desktop app's refresh token, and Claude-Usage-Tracker shipped the bug and had to undo it.

So when an account's access token has expired (because that copy has been closed for a while), its row says **"Open Claude B to update"** and keeps the last numbers greyed with their age. Clicking the row opens that copy, it refreshes its own token, and the next poll works.

Measured in milestone 1: the desktop app's access tokens last about 30 days (all three profiles showed 26–30 days left), so this state will be rare.

### Polling and rate limits

- Poll each account every **5 minutes**, staggered so the three calls don't land together.
- Opening the panel refreshes any account older than 60 seconds.
- `/api/oauth/usage` is known to return **429**, sometimes for hours and with `Retry-After: 0` or none. On a 429, back off exponentially per account (5 min, 10, 20 … capped at 6 h), honour a real `Retry-After`, and show the last good numbers with their age.
- Pause on sleep and poll on wake.
- Never fall back to a paid call: Claude-Usage-Tracker's 1-token Haiku message reads the rate-limit headers but costs usage.

## The notch

### Approach: our own panel, not a library

Build a ~200-line `NSPanel` rather than use DynamicNotchKit. DynamicNotchKit has no hover-to-expand, can't keep the collapsed state on a screen without a notch, picks the screen by index, and its panel is half the screen and blocks clicks. Borrow from the two small MIT apps that already do nearly this: quota-notch's `NotchGeometry` and `HoverGate`, and ClaudeUsageNotch's `NotchPillShape` and hover polling. Read boring.notch for ideas only: it's GPL-3.0.

### Geometry

- **Choose the screen:** the first screen with `safeAreaInsets.top > 0`, else the built-in display (`CGDisplayIsBuiltin`), else `NSScreen.main`.
- **Notch rect:** `x = auxiliaryTopLeftArea.maxX`, `width = auxiliaryTopRightArea.minX - x`, height `safeAreaInsets.top`, top-aligned. The two side areas aren't symmetric, so don't derive it from the screen width.
- **Rings:** small (about 14pt), just outside the notch's right edge in `auxiliaryTopRightArea`, so they cover as few menu bar icons as possible. They don't take clicks; clicks pass through to the menu bar.
- **No notch** (external monitor, clamshell, older Mac): a 160–176pt pill at the top centre of the menu bar, 24pt tall (not `frame.maxY - visibleFrame.maxY`, which is 0 when the menu bar auto-hides), with the rings inside it and the same hover.

### Window

- `NSPanel`, `[.borderless, .nonactivatingPanel]`, `isFloatingPanel`, `hidesOnDeactivate = false`, clear background, no shadow, not movable, dark appearance.
- Level `.statusBar + 1`, and override `constrainFrameRect` to return the frame unchanged so AppKit doesn't push the panel below the menu bar.
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`.
- `canBecomeKey` and `canBecomeMain` return false; clicking a row runs the launcher without the panel taking focus.
- Never set `ignoresMouseEvents`. Left alone, transparent pixels pass clicks through; setting it to `false` turns that off for good.
- No Dock icon: `LSUIElement = YES` and `NSApp.setActivationPolicy(.accessory)` at launch.

### Hover

Poll `NSEvent.mouseLocation` on a timer in `.common` run-loop mode (every 0.05s), as both small apps do; tracking areas are unreliable on non-activating panels that resize.

- **Trigger:** the notch cutout itself, not the strip below it, so reaching for a tab doesn't open the panel.
- **Timing:** open after 0.08s inside; close 0.35s after the pointer leaves the open panel.
- **Mouse button down:** never open while a mouse button is held (dragging).

### States per row

| State | Shows |
| --- | --- |
| OK | Email, 5-hour bar and reset, weekly bar and reset, per-model bars |
| At a limit | That bar full in red, "out until Sat 14:00" |
| Stale (token expired) | Greyed last numbers with age, "Open Claude B to update" |
| Rate-limited | Last numbers with age, small "retrying in 20m" |
| Not signed in | "Sign in to Claude C" |
| Keychain denied | One banner across the panel: "Allow Keychain access to read usage", with a retry |
| Endpoint changed | "Usage unavailable" (never wrong numbers) |
| Another organization | Under the one in use: its plan, "not in use", its own bars |
| No login for the organization in use | "No login for this organization yet" |
| Plan without limits | "No usage limits on this plan" |

Ring colour: the account's colour, the outer ring turning red at 90% of the 5-hour window. The inner ring follows the fullest weekly window (all models or per model). When that is at 100%, a small red cross replaces the inner ring: that account is out for the week whatever the 5-hour ring says.

### Lifecycle

- **Displays:** rebuild the panel on `didChangeScreenParametersNotification` only when the set of displays or their frames changed, comparing UUIDs and frames.
- **Sleep:** re-order the panel to the front on wake; boring.notch users report it vanishing after long sleeps.
- **Login:** starts at login through `SMAppService.mainApp`.

## Fitting in with what exists

- **Profile names, colours and keys** live in `~/.config/claude-multi-account/profiles.json` (`letter`, `label`, `color`, `hotkey`; template in `files/profiles.json`). The app and `claude-usage` read it, so adding Claude D is one line. Without the file both use A blue, B orange and C green on ⌥⌘1/2/3. Email labels come from `/api/oauth/profile` automatically.
- **Switching:** clicking a row or pressing a hotkey runs `~/Applications/Claude <letter>.app/Contents/Resources/claude-profile.sh <letter>`, including the reopen fix. Then, like Hammerspoon did, it asks a running copy to come forward again (every 0.3 s, up to four times) until it's in front, because macOS sometimes ignores activating one of several copies of an app.
- **Hammerspoon and the link router are retired.** Planned at first to stay for the outline, hotkeys and links, they were folded into the app instead, so one thing runs at login rather than three. Carbon hotkeys, the window list and an Apple event need no Accessibility permission, which Hammerspoon's outline did. The menu bar label went with them: the outline shows which copy is in front, and the panel says where links go.

## Structure

A Swift package in `notch/` in this repo, Swift 6.2, macOS 26, no third-party dependencies (CommonCrypto for PBKDF2 and AES; Security for the Keychain).

| Module | Does |
| --- | --- |
| `UsageCore` | Profile discovery, Keychain key, decryption, entry selection, `UsageClient` (usage and profile calls, lenient decoding), scheduler with backoff. No UI. |
| `claude-usage` | `claude-usage [--json] [--verbose] [--only B,C]`: prints every account's limits. Milestone 1's proof, and handy for scripts. |
| `ClaudeNotch` | The app: panel, geometry, hover gate, SwiftUI views, launcher calls, login item; and the copies (which is which, used last), hotkeys, window outline and `claude://` routing. |

Build it with `swift build` plus a short script that wraps the binary in an `.app` with `LSUIElement` and signs it ad hoc. The app has a stable bundle ID (`com.godzillaaa.claude-notch`), so the Keychain's Always Allow sticks across rebuilds. Rebuilding with a new ad hoc signature may re-prompt; if it does, sign with a local development certificate.

## Milestones

| # | Delivers | Done when |
| --- | --- | --- |
| 1 | `UsageCore` + `claude-usage` CLI | `claude-usage` prints the 5-hour, weekly and per-model numbers for A, B and C, matching each app's Settings → Usage. One Keychain prompt. Measured how long an access token lasts. |
| 2 | Notch panel, hover, rows | Hovering the notch shows three correct rows; clicking a row switches to that Claude; no Dock icon; clicks beside the rings reach the menu bar. |
| 3 | States and resilience | Stale, rate-limited, not-signed-in and Keychain-denied states each tested by forcing them; backoff verified; survives sleep, display changes and a full-screen app. |
| 4 | No-notch fallback, login item, shared profiles file | Works on an external display with the lid shut; starts at login; ~~Hammerspoon reads `profiles.json`~~ the app replaces Hammerspoon and reads `profiles.json`; README updated. |

Unit tests (XCTest via `swift test`) cover decryption against a fixture encrypted with a known password, entry selection, response decoding (old fields, `limits[]`, nulls, microsecond dates), backoff timing and notch geometry. Fixtures hold no real tokens.

## Risks

| Risk | Effect | Handling |
| --- | --- | --- |
| `/api/oauth/usage` is undocumented | A Claude change breaks or reshapes it | Lenient decoding; "Usage unavailable" rather than wrong numbers; all parsing in one file |
| The desktop app changes how it stores tokens (new key name, new encryption version) | Logins can't be read | Detect it and show "Can't read Claude's login"; isolated in one reader; openusage and TokenEater track the same format |
| Long 429 spells | Numbers go stale for hours | Show the age; back off; never retry hard |
| Reading another app's encrypted login | Sensitive data handled by our app | Read only; key and tokens in memory only; tokens never logged or written; the only network calls are the two Anthropic endpoints |
| Terms of service | Using the OAuth token outside Claude's own apps | The same read-only usage check many popular tools make; no inference calls. Note it, accept it for personal use |
| macOS notch quirks (full-screen title bars, Mission Control overlap, long-sleep disappearance) | Cosmetic glitches | Known from boring.notch issues; re-order on wake; test on the real machine |

## What milestone 1 found

Run on 2026-10-17 against all three profiles:

- **Reading works:** one Keychain prompt for the CLI, then all three logins decrypted and both endpoints answered in under 5 seconds. A's numbers matched Claude's own usage card for that account (5-hour reset time and weekly 100%).
- **Logins last about 30 days**, not hours.
- **Plans differ:** A and B (Max) have 5-hour, weekly all-models and weekly Fable windows. C (Team) has 5-hour and weekly Fable only, with no all-models weekly window. The UI must not assume a weekly all-models window exists. For a Team account, the cross on the ring follows whichever weekly window is at 100%.
- **A 5-hour window that hasn't started** comes back with no reset time (B showed 0% with no reset). Show "not started" rather than a blank.
- **A wrong key isn't always caught at decryption:** it can pass the padding check and give garbage. Bad JSON after decrypting is treated the same as a failed decrypt.

## What milestone 2 built

`notch/Sources/ClaudeNotch`, run from `notch/build/Claude Notch.app` (`scripts/build-app.sh`):

- **Two windows.** The rings sit in a small black shape that continues the notch to the right. That window ignores the mouse, so clicks on it reach the menu bar. The open panel is a second `NSPanel` with the window flags above, shown only while open.
- **Hover** follows the rules above (`HoverGate`, sampled every 0.05 s). The trigger is the notch cutout only, not the rings, so reaching for a menu bar icon under the rings doesn't open the panel. After a row is clicked the panel closes, and won't reopen until the pointer has left the notch.
- **Rows**: the badge in the account's colour, email, plan, and one bar per window with its percentage and "resets in 2h 10m" (within a day), "resets Sat 14:00" (beyond) or "out until Sat 14:00" (at 100%). An unstarted 5-hour window says "not started". Bars turn red at 90%. Clicking a row runs that letter's launcher script.
- **Polling** (`PollPlan` in UsageCore): every account is read at launch in one call, then every 5 minutes, with accounts read together pushed apart by a third of the interval each. Opening the panel re-reads accounts older than a minute. A 429 backs off 5, 10, 20 minutes … up to 6 hours, or follows a real `Retry-After` (kept between 1 minute and 6 hours). Polling pauses on sleep. On wake the windows are brought to the front and everything not backing off is read.
- **States** are drawn already (stale, rate-limited, not signed in, the Keychain banner with Retry, "Usage unavailable"). A refused Keychain prompt stops polling until Retry, so it isn't shown again every 5 minutes. Forcing each state is milestone 3's job.
- **Displays**: the windows are rebuilt only when the set of displays or their frames change. A screen without a notch already gets the pill; milestone 4 tests it with the lid shut.
- **Checking it without screen recording**: `--pin` keeps the panel open, and `--snapshot <file.png>` renders the rings and panel with live numbers to a PNG and quits.

## What milestones 3 and 4 built

**States (milestone 3).** `--demo` fills the panel with made-up accounts in every state: OK; out for the week in a Team with the 5-hour bar past 90%; a rate-limited personal plan beside it ("retrying in 19m · 12m ago"); an expired login with greyed numbers ("Open Claude C to update"); a plan with no limits; signed out; "Usage unavailable"; "No login for this organization yet"; and the Keychain banner. `--demo --snapshot file.png` renders it, and each state was checked that way. The model tests force each state through the same code the poller uses: a passing failure keeps the last numbers with their age; signing out clears them; a refused Keychain stops polling; per-account 429 backoff runs 5, 10, 20, 40 minutes, a real `Retry-After` wins and a good read resets it; opening the panel doesn't cut a backoff short.

**Not yet checked by hand:** sleep and wake, plugging displays in and out, and a full-screen app. The code for each is in place (rebuild only on a real display change, bring to front and re-read on wake, `.fullScreenAuxiliary`), but only using the Mac will show the boring.notch-style glitches.

**Milestone 4.**

- **No notch:** `--no-notch` forces the pill, and the pill renders correctly in a snapshot. Not yet tried on an external display with the lid shut.
- **Login item:** `SMAppService.mainApp`. The first launch from an Applications folder turns it on, once; after that the panel's **Open at login** toggle decides. A build-folder copy never adds itself.
- **profiles.json:** as above.
- **Installing:** `scripts/build-app.sh --install` copies the app to `~/Applications`, unregisters the build-folder copy from Launch Services so links can't land there, and opens it. A second copy started while one runs (for example by a link) passes its link on and quits.
- **Keychain:** the first launch from `~/Applications` asked for Keychain access again, although the signature's designated requirement hadn't changed. Not yet known whether the new path or the changed binary caused it; watch whether the next `--install` asks.

**Hammerspoon's jobs, now in the app:**

- **Which copy is which:** a running Claude's letter comes from its `--user-data-dir` argument (none or `…/Claude` is A, `…/Claude-B` is B), read from the kernel (`KERN_PROCARGS2`) rather than `ps`. Activation notifications give the copy in front and the one used last, which is kept across restarts.
- **Hotkeys:** Carbon `RegisterEventHotKey`, ⌥⌘ plus each profile's key. Taken keys are logged.
- **Outline:** a click-through panel at floating level, 4 pt line, 3 pt outside the window, 14 pt corners, as before. The window's frame comes from `CGWindowListCopyWindowInfo`, sampled every 0.05 s only while a Claude copy is in front. It's hidden when the window fills its screen.
- **Links:** the app declares `claude://`, takes the default handler at launch and 5 s after any Claude copy starts, and passes each link to the copy used last (else the first running, else it starts Claude). The link travels as a `GURL` Apple event sent to that process, as Hammerspoon sent it. macOS asks once whether the app may control Claude.
- **Logging:** failures and a startup line go to the unified log, subsystem `com.godzillaaa.claude-notch`.

Checked live after installing: ⌥⌘1/2/3 registered, the running copies identified as A, B and C, and `claude://` taken from Claude. Pressing the hotkeys, the outline following a window, and a sign-in link reaching the right copy still need trying by hand.

## Open questions

1. Does the per-account email from `/api/oauth/profile` replace the "Claude A/B/C" labels everywhere, or sit under them? Answered: the email in the panel, the letter on the badge and rings, the colour on the outline. The `label` in profiles.json shows only when there's no email yet. Messages name the launcher ("Open Claude B"), not the label.
2. Should the ring show the 5-hour window or "whichever limit is closest"? Proposed: the 5-hour window, with the weekly cross.
3. Is a notification wanted when an exhausted account comes back? Proposed: later, off by default.
4. Signing: is ad hoc enough for Keychain Always Allow to stick, or do we need a development certificate? Answered: "Always Allow" is tied to the binary's signature, and an ad hoc signature changes with every build, so each rebuild asks again (the first run after each of two builds waited about 4.7 s on the prompt; later runs took 0.3 s). So `scripts/build-app.sh` signs the app with a certificate: `$CODESIGN_IDENTITY`, else the first code-signing identity in the login Keychain (on this Mac a local self-signed one), else ad hoc with a warning. The designated requirement is then the bundle ID plus that certificate, which stays the same across rebuilds.

## Prior art

| Project | Licence | What we take |
| --- | --- | --- |
| [robinebers/openusage](https://github.com/robinebers/openusage) | MIT | Decrypting `oauth:tokenCacheV2`, entry ranking, never touching the refresh token (`Providers/Claude/ClaudeDesktopAuthStore*.swift`) |
| [AThevon/TokenEater](https://github.com/AThevon/TokenEater) | MIT | Electron decryption in Swift (`ElectronDecryptionService.swift`), 429 backoff to 6 h |
| [steipete/CodexBar](https://github.com/steipete/CodexBar) | MIT | Usage response decoding (`ClaudeOAuthUsageFetcher.swift`), owner-only refresh rule, 429 handling |
| [akitaonrails/ai-usagebar](https://github.com/akitaonrails/ai-usagebar), [xiaolai/claudepot-app](https://github.com/xiaolai/claudepot-app) | MIT, ISC | Cross-checks of the token cache format (V2 vs V1) |
| [aghoc/quota-notch](https://github.com/aghoc/quota-notch) | MIT | `NotchGeometry`, `HoverGate`, `constrainFrameRect` override |
| [momonala/ClaudeUsageNotch](https://github.com/momonala/ClaudeUsageNotch) | MIT (licence file in `swift-project/ClaudeUsageNotch/`) | `NotchPillShape`, hover polling, the no-notch pill |
| [mrkai77/DynamicNotchKit](https://github.com/mrkai77/DynamicNotchKit) | MIT | `NotchShape.swift` if useful; not the library itself |
| [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch) | GPL-3.0 | Ideas only (window flags, display-change handling); no code |
| [hamed-elfayome/Claude-Usage-Tracker](https://github.com/hamed-elfayome/Claude-Usage-Tracker) | MIT | Lessons: its refresh bug and its paid-call fallback, both avoided |

None of these shows several accounts at once; that, and the notch, is what's new here.
