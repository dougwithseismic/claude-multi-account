# PRD 04: Web tools

Status: shipped 2026-10-19.

## Goal

Tools that help in the browser, with nothing to install, for anyone who uses Claude, including people on Windows and Linux who can't run the Notch. They answer the questions the Notch answers for its users ("will I run out before it resets?") and turn visitors into installers when they're on a Mac.

## Locked decisions

- `/tools` lists the tools; each is its own prerendered page that works offline once loaded. All the maths is in one pure module with tests.
- Nothing is sent anywhere. Inputs can be kept in the URL's hash so a result can be shared.
- The look is the panel's: the same bars, tick and red.

## Tools

### Pace calculator (`/tools/pace`)

Inputs: which window (5-hour or weekly), percent used, and when it resets (in hours and minutes, or a clock time).

Shows:
- how far through the window you are, and where the pace tick would sit;
- whether you're ahead of or behind an even pace, by how much;
- at this rate, when you'd reach 100%, and whether that's before the reset;
- how much you can use per hour from now to last exactly until the reset.

### Setup planner (`/tools/setup`)

Inputs: how many accounts, and for each a label, colour and hotkey (defaults A blue, B orange, C green, D purple…).

Shows the rings as the Notch would draw them, the memory to expect (0.5–1 GB per open copy, as the README says), the `install.sh` command for that many copies, and the `profiles.json` to paste, each with a copy button.

## Acceptance criteria

- WHEN someone enters 60% used with 2 hours left of a 5-hour window the system SHALL say they're 60% through, on an even pace, and would reach 100% just as it resets.
- WHEN the projected time to 100% is before the reset the system SHALL show the run-out time and the time left without Claude, in red.
- WHEN someone changes an input the system SHALL update the result without a button press and keep the inputs in the URL hash.
- WHEN someone opens a shared link the system SHALL restore its inputs.
- WHEN someone picks 5 accounts in the setup planner the system SHALL show `./install.sh 5`, five rings, and a `profiles.json` with A to E.
- WHEN the pace maths is tested the system SHALL pass the cases above and the edges (0%, 100%, reset already passed, no time elapsed).

## Tasks

1. `src/lib/pace.ts` and its tests.
2. Pace calculator page.
3. Setup planner page.
4. `/tools` index, nav and footer links.

## Implementation notes

Shipped 2026-10-19.

- `src/lib/pace.ts` holds the maths (12 tests, `pnpm --filter @claude-notch/web test`, run with Node's own test runner on the `.ts` file). Within 2 points of even counts as even; a minute's slack stops "100% just as it resets" being reported as running out.
- Pace calculator: 5-hour or weekly, percent used, and the reset either "in" a duration or "at" a clock time (and day, for weekly). The hash keeps the inputs (`#w=5h&used=60&in=120`). The clock time is only worked out in the browser, since the prerendered page has no "now".
- Setup planner: 2 to 9 accounts. With the defaults it shows `install.sh N`; once a name, colour or hotkey changes it shows a three-step flow that writes profiles.json before the installer runs, because the installer never overwrites an existing profiles.json. Warns when two accounts share a hotkey.
- Checked in the browser: 60% with 2 hours left shows "On an even pace" and 60% through; 80% with 3 hours left shows the run-out time and 2h 30m without Claude in red; 5 accounts shows `install.sh 5`, five rings and A to E.
