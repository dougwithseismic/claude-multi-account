# The Notch film: shot list and plan

A short film of Claude Notch for the marketing page (`apps/web`), plus a silent loop for the hero. The story the site leads with: you no longer sign out and back in to switch Claude accounts, because every account runs at once, each signed in to its own copy of Claude, and the notch shows every copy's 5-hour and weekly limits.

## Deliverables

In `apps/web/public/video/`:

| File | What |
| --- | --- |
| `notch-film.webm`, `notch-film.mp4` | The film, 59 s, 1920×1080, 60 fps, silent |
| `notch-film-poster.jpg` | Its poster frame: the panel open over the three windows |
| `notch-hero.webm`, `notch-hero.mp4` | The hero loop, 12 s, 1600×900, 60 fps, seamless, silent, no captions |
| `notch-hero-poster.jpg` | Its first frame, so the loop starts where the poster leaves off |

WebM is VP9, MP4 is H.264 (`+faststart`), both without an audio track, so either autoplays muted.

## How it's made

Everything on screen is the real app: its windows, views, springs, hover gate, peeks, outline and settings page, built from `apps/notch/Sources/ClaudeNotch`. Only the data is made up and the input is scripted.

**Why not `ClaudeNotch --demo --pin`.** Read from the source: `--pin` keeps the panel open and turns off the hover gate, and `peek()` returns early while pinned, so there is no opening, no switch peek and no alert. `--demo` also fills six copies with every error state (signed out, "Usage unavailable", the Keychain banner), which is right for checking states and wrong for a film. And the demo skips the window outline, since it has no Claude copies to follow.

**The director** (`apps/notch/film/`). `make-film.sh build` copies the app's sources (all but `App.swift`, the entry point) next to the director's own (`film/Sources`: `Film.swift` the takes, `Stage.swift` the set and overlay, `Input.swift` the pointer and ⌥, `Footage.swift` the made-up copies) into a throwaway package under `.build/film`, builds it and wraps it as an app with the real app's version number. The director then plays one take on the real screen:

- **Data.** `AccountsModel(reader: nil)`, as the demo does: nothing is read, no Keychain, no network. Three copies, A, B and C, with made-up plans and `@example.com`-style emails. The footer shows what a real install shows ("Updated just now · Links go to Claude A") rather than the demo's "made-up accounts" line.
- **Stage.** A full-screen backdrop behind everything (black, with the site's hero art: three soft rings in the profile colours and the blue glow), a strip over the menu bar with the notch drawn in, so the menu bar's real contents never appear, and three stand-in "Claude A/B/C" windows, one per copy. The outline follows these with the app's own `Outline` class.
- **Input.** The pointer is real: the director moves and clicks it with Quartz events, so the hover gate, row hover and clicks run through the app's own code. Screen recording leaves the real pointer out, so the overlay draws the system arrow where it is, a little larger than life, with a soft ring on each click. Leaving the open panel, the pointer slides out along the top edge first, so it doesn't cross the rows (their reset times turn into clock times under the pointer). Holding ⌥ is faked inside the director's process only (`NSEvent.modifierFlags`), so no key reaches another app. ⌥⌘1/2/3 call the same two lines the hotkey handler runs (switch, then peek); a keycap on screen shows the keys.
- **Installed copy.** The settings page dims "Open at login" for a copy outside an Applications folder. The director answers `Bundle.main.bundleURL` with `/Applications/Claude Notch.app`, so the row looks as it does in an installed app (off, since the film's copy isn't a login item).
- **Captions, title and end card** are drawn live by the director in an overlay above everything, in Geist with the serif italic accent the site's headings use, so the take needs no compositing.
- **Sync.** Each take flashes a small white square in a corner outside the final crop at known moments, so the edit can find cue points exactly.

**Recording.** `make-film.sh record film|hero` quits the installed `~/Applications/Claude Notch.app` first (its rings and hotkeys would sit on top of the director's) and reopens it afterwards. `ffmpeg -f avfoundation` records the top-centre of the built-in display at 60 fps: a 1024×576 pt region (2048×1152 px) centred on the notch, of which the film uses the middle 1920×1080, converted once to BT.709 and kept at 120 Mb/s for the edit. Colours come through as sRGB (the traffic lights sample within a few levels of their values). Nothing else on the Mac should move while a take runs: the pointer is driven, and a click elsewhere would bring another window forward.

**Edit.** `make-film.sh edit`, ffmpeg only: trim each take at its sync marks, crop, fade out, encode (H.264 CRF 20, VP9 CRF 34) and grab the poster. The film starts 0.3 s after its first mark and runs 59.2 s. The hero is the second of three identical cycles, cut mark to mark, so the last frame leads straight into the first.

## Shot list (film)

Times are the film's.

| # | Time | Shot | What the app does | Caption |
| --- | --- | --- | --- | --- |
| 1 | 0–3.4 s | Title on black | | Sign in once. Run every Claude account *side by side.* |
| 2 | 3.4–7.2 s | The stage fades up: three Claude windows, A in front with a blue outline | Rings start empty, then fill on a spring | Each account runs in its own copy of Claude, *signed in for good.* |
| 3 | 7.2–9.8 s | The closed notch | Three rings beside the notch: outer 5-hour, inner weekly, the dot under A | Every account's 5-hour and weekly limits, *beside the notch.* |
| 4 | 9.8–13.5 s | The pointer comes up and rests on the notch | The panel springs out of the notch, rows slide in, bars fill | Rest on the notch to *see them all.* |
| 5 | 13.5–15.8 s | ⌥ held (keycap on screen) | Names turn into emails, plans gain their teams; "Showing details" | Names stay private until you *hold ⌥.* |
| 6 | 16.2–19.6 s | The pointer moves to B and clicks | Row B lights up with its ⌥⌘2 hint and resets by the clock; the panel folds, the dot slides to B, B's window comes forward in orange | Click a row to switch. *Nobody signs out.* |
| 7 | 19.6–23.6 s | ⌥⌘3, then ⌥⌘1 (keycaps on screen) | Switch peeks name C, then A, with their 5-hour and weekly figures; the outline turns green, then blue | Or press ⌥⌘1, 2 or 3 *from anywhere.* |
| 8 | 23.6–31.4 s | Alerts | B passes 90%: "Claude B · 5-hour at 91%" with its reset; then "5-hour used up" and B's ring turns red | A word under the notch at *90%*, and when one runs out. |
| 9 | 31.4–37.9 s | Every copy out | All three rings red; "C 0:06" beside them counts down | All out? It counts down to the *first one back.* |
| 10 | 37.9–40.8 s | C comes back | "Claude C · 5-hour reset · ready again" | And it tells you when one's *back.* |
| 11 | 40.8–48.1 s | Settings | Rest on the notch, click the gear: the settings page | Open it on hover or click. Alerts, peeks and haptics are *up to you.* (cleared while the page is up) |
| 12 | 48.1–54.4 s | A display without a notch | The notch gives way to the pill; resting on it opens the same panel | No notch? It sits in a *pill* on any display. |
| 13 | 54.4–59.2 s | End card on black | | Claude Notch. Every Claude account, *signed in at once.* Free for macOS 26 |

## Hero loop

No captions, no windows, the same backdrop standing still, a 1600×900 crop on the notch. One cycle, 12 s: the closed rings; the pointer rests on the notch and the panel opens; it holds; the pointer leaves and the panel folds; ⌥⌘2 and B's switch peek; ⌥⌘1 and A's; back to the closed rings with A current, so the last frame matches the first.

## Not covered

- Sound: there is none. A soundtrack or UI sounds would need music we have a licence for.
- The film shows the pill on the built-in display with the notch hidden, not on a real external display; the app draws the same pill either way (`--no-notch` exists for exactly this).
- Signing in, `claude://` links and starting a closed copy aren't shown; they don't read on screen.
