# PRD: Claude usage in the notch

Status: draft, 2026-10-17. Nothing built yet.

## Problem

I run three Claude accounts side by side (Claude A, B and C; see the [README](../README.md)). Each has a 5-hour limit and weekly limits, and I switch accounts when one runs out. Today the only way to see an account's limits is to open that copy of Claude and go to Settings → Usage, one account at a time. I find out an account is spent when it stops answering.

## What we're building

A small native Mac app that sits at the MacBook notch and shows every account's limits at a glance:

- **Collapsed:** one small ring per account beside the notch, in the account's colour (A blue, B orange, C green), filled to that account's 5-hour use.
- **Hover the notch:** a panel drops down with one row per account: the account's email, the 5-hour bar with "resets in 2h 10m", the weekly bar with its reset, and any per-model weekly bars (for example Fable).
- **Click a row:** switches to that Claude, using the existing launchers.

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
4. **Pick an entry**, using openusage's rules: drop entries whose user UUID doesn't match `lastKnownAccountUuid`, require the `user:profile` scope, prefer entries that also carry `user:inference`, then more scopes, then the latest `expiresAt`.

Use `oauth:tokenCacheV2` only: signing in moves the live token there and empties V1. The app never reads, decodes or uses `refreshToken` (see [Refreshing](#refreshing-never)).

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

`GET https://api.anthropic.com/api/oauth/profile` with the same token returns the account's email and org, which become the row labels. That also answers the earlier wish to see which account is which.

Decode leniently: unknown fields are ignored and a missing window just isn't shown, because the endpoint is undocumented and gains fields over time.

### Refreshing: never

Refreshing a token rotates its refresh token, so the Claude copy that owns it is left holding a dead one and gets signed out. Every serious project avoids this: openusage won't even decode the desktop app's refresh token, and Claude-Usage-Tracker shipped the bug and had to undo it.

So when an account's access token has expired (because that copy has been closed for a while), its row says **"Open Claude B to update"** and keeps the last numbers greyed with their age. Clicking the row opens that copy, it refreshes its own token, and the next poll works.

How long the desktop app's access tokens last is unverified. Measure it in the first milestone.

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

Ring colour: the account's colour, turning red at 90% of the 5-hour window. If the weekly window is at 100%, the ring shows a small cross: that account is out for the week whatever the 5-hour ring says.

### Lifecycle

- **Displays:** rebuild the panel on `didChangeScreenParametersNotification` only when the set of displays or their frames changed, comparing UUIDs and frames.
- **Sleep:** re-order the panel to the front on wake; boring.notch users report it vanishing after long sleeps.
- **Login:** starts at login through `SMAppService.mainApp`.

## Fitting in with what exists

- **Profile names, colours and keys:** these live in the Hammerspoon config today. Move them to `~/.config/claude-multi-account/profiles.json` (`letter`, `label`, `color`, `hotkey`). The notch app and `init.lua` both read it, so adding Claude D is one line. Email labels come from `/api/oauth/profile` automatically.
- **Switching:** clicking a row runs `~/Applications/Claude <letter>.app/Contents/Resources/claude-profile.sh <letter>`, the same path the hotkeys use, including the reopen fix.
- **Hammerspoon** keeps the window outline, hotkeys and link router. Once the notch is working, its menu-bar label becomes redundant and can go.

## Structure

A Swift package in `notch/` in this repo, Swift 6.2, macOS 26, no third-party dependencies (CommonCrypto for PBKDF2 and AES; Security for the Keychain).

| Module | Does |
| --- | --- |
| `UsageCore` | Profile discovery, Keychain key, decryption, entry selection, `UsageClient` (usage and profile calls, lenient decoding), scheduler with backoff. No UI. |
| `usage-cli` | `claude-usage [--json]`: prints every account's limits. Milestone 1's proof, and handy for scripts. |
| `ClaudeNotch` | The app: panel, geometry, hover gate, SwiftUI views, launcher calls, login item. |

Build it with `swift build` plus a short script that wraps the binary in an `.app` with `LSUIElement` and signs it ad hoc. The app has a stable bundle ID (`com.godzillaaa.claude-notch`), so the Keychain's Always Allow sticks across rebuilds. Rebuilding with a new ad hoc signature may re-prompt; if it does, sign with a local development certificate.

## Milestones

| # | Delivers | Done when |
| --- | --- | --- |
| 1 | `UsageCore` + `claude-usage` CLI | `claude-usage` prints the 5-hour, weekly and per-model numbers for A, B and C, matching each app's Settings → Usage. One Keychain prompt. Measured how long an access token lasts. |
| 2 | Notch panel, hover, rows | Hovering the notch shows three correct rows; clicking a row switches to that Claude; no Dock icon; clicks beside the rings reach the menu bar. |
| 3 | States and resilience | Stale, rate-limited, not-signed-in and Keychain-denied states each tested by forcing them; backoff verified; survives sleep, display changes and a full-screen app. |
| 4 | No-notch fallback, login item, shared profiles file | Works on an external display with the lid shut; starts at login; Hammerspoon reads `profiles.json`; README updated. |

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

## Open questions

1. Does the per-account email from `/api/oauth/profile` replace the "Claude A/B/C" labels everywhere, or sit under them? Proposed: show the email in the panel and keep the letter on the rings and outline.
2. Should the ring show the 5-hour window or "whichever limit is closest"? Proposed: the 5-hour window, with the weekly cross.
3. Is a notification wanted when an exhausted account comes back? Proposed: later, off by default.
4. Signing: is ad hoc enough for Keychain Always Allow to stick, or do we need a development certificate? Answered in milestone 1.

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
