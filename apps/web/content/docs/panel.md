---
title: Reading the panel
description: What the rings, bars, ticks and every message in the notch panel mean.
section: Using it
order: 4
---

## The rings

Collapsed, Claude Notch is one double ring per copy, just right of the notch, in that copy's colour.

- The **outer ring** is the 5-hour window. It turns red at 90%.
- The **inner ring** is the fullest weekly window: all models, or one model's own weekly limit, whichever is higher.
- A **red cross** in place of the inner ring means that account is out for the week, whatever the outer ring says.
- A **dot** under a ring marks the copy in front.
- With every copy out, the closed notch counts down to the first one back.

The rings never take clicks, so the menu bar icons under them still work. On a screen without a notch, the rings sit in a small black pill at the top centre.

## The panel

Rest the pointer on the notch, or click it, and the panel grows out of it with one row per copy: its name, its plan, and a bar for each limit window with when it resets. Click a row to switch to that copy. Move away and the panel folds back into the notch.

- **Bars** fill with that window's use and turn red at 90%.
- The **white tick** on a bar marks how far through its window you are. A bar past its tick is being used faster than an even pace would last. [Pacing your limits](/learn/pacing) explains how to read it.
- **Reset times** read "resets in 2h 10m" within a day and "resets Sat 14:00" beyond. Rest on one to see it as a clock time.
- A 5-hour window that hasn't started yet says **not started**.

## Teams and other organizations

One login can belong to several organizations, for example a personal Max plan and a Team, each with its own limits. A copy's row shows the organization it's working in (whichever you last picked in Claude's account menu), and any other organization below it, marked **not in use**.

An organization you've never used in that copy, a free personal plan say, has no login and isn't shown. [Teams and organizations](/learn/teams-and-organizations) covers how Claude decides which limits apply.

## Every message

| The panel says | What it means | What to do |
| --- | --- | --- |
| **out until Sat 14:00** | That window is at 100% | Wait for the reset, or switch to a copy with room |
| **Open Claude B to update** | That copy's login has expired because it's been closed a while; the numbers are greyed with their age | Open that copy. It renews its own login and the next read works |
| **retrying in 20m** | Anthropic rate-limited the usage check | Nothing: it backs off and shows the last numbers with their age |
| **Sign in to Claude C** | That copy has no login | [Sign in to it](/docs/sign-in) |
| **Allow Keychain access to read usage** | The Keychain prompt was refused | Click **Retry** and choose **Always Allow** |
| **Waiting for Keychain access** | The Keychain prompt is open, maybe behind a window | Find the prompt, enter your password, choose **Always Allow** |
| **Usage unavailable** | The usage check answered in a way the app doesn't understand | Update Claude Notch; it never shows numbers it isn't sure of |
| **No login for this organization yet** | The copy is set to an organization it hasn't used yet | Use Claude in that organization in that copy; that creates a login the app can read |
| **No usage limits on this plan** | Some Team and Enterprise plans report no windows at all | Nothing |
| **Switch Claude B to this organization to update** | Claude only renews the login of the organization in use | Pick that organization in that copy's account menu once |

## Privacy

Rows show the profile's name ("Claude B") and plan, never the email or a Team's name, so the panel can open in front of anyone. The eye at the top left shows them; holding <kbd>⌥</kbd> over the panel shows them until you let go.

## Peeks

After a <kbd>⌥⌘</kbd> switch, a strip under the notch names the copy for a moment. When the copy in use passes 90% of its 5-hour limit, runs out of a limit, or gets one back, the strip says so for a few seconds. Peeks never take clicks and stay away while an app is full screen.
