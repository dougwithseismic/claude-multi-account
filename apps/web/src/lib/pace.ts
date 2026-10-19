/**
 * Pace maths for a usage window, shared by the pace calculator and the guides.
 * Everything is in minutes and percent (0–100), with no clock: callers pass how long
 * the window is and how long until it resets.
 */

export const windows = {
  fiveHour: { label: '5-hour', minutes: 5 * 60 },
  weekly: { label: 'Weekly', minutes: 7 * 24 * 60 },
} as const

export type WindowKind = keyof typeof windows

/**
 * - `reset`: the reset time has passed, so these numbers are from the last window.
 * - `out`: at 100%.
 * - `early`: under a minute in, too soon to tell a rate.
 * - `over`, `even`, `under`: using faster than an even pace, about even, or slower.
 */
export type PaceState = 'reset' | 'out' | 'early' | 'over' | 'even' | 'under'

export type Pace = {
  state: PaceState
  /** How far through the window it is, 0 to 1. Where the panel's tick sits. */
  elapsed: number
  /** Minutes until it resets. */
  left: number
  /** Percent used minus percent of the window gone, in points. Positive is faster than even. */
  gap: number
  /** Percent an hour so far. */
  rate: number
  /** Minutes until 100% at the rate so far, or null if it won't get there (or can't tell). */
  runOutIn: number | null
  /** True when that's before the reset. */
  runsOut: boolean
  /** Minutes at 100% before the reset, when it runs out. */
  without: number
  /** Percent an hour that would last exactly until the reset. */
  budget: number
}

/** Within this many points of an even pace counts as even. */
export const evenWithin = 2

export function pace({
  used,
  length,
  left,
}: {
  /** Percent used, 0–100. */
  used: number
  /** The window's length in minutes. */
  length: number
  /** Minutes until it resets. */
  left: number
}): Pace {
  const pct = clamp(used, 0, 100)
  const remaining = clamp(left, 0, length)
  const gone = length - remaining
  const elapsed = length > 0 ? gone / length : 0
  const gap = pct - elapsed * 100
  const base = {
    elapsed,
    left: remaining,
    gap,
    rate: 0,
    runOutIn: null,
    runsOut: false,
    without: 0,
  }

  if (!(left > 0)) return { ...base, state: 'reset', elapsed: 1, gap: 0, budget: 0 }
  if (pct >= 100) {
    return { ...base, state: 'out', runOutIn: 0, runsOut: true, without: remaining, budget: 0 }
  }

  const budget = ((100 - pct) / remaining) * 60
  if (gone < 1) return { ...base, state: 'early', budget }

  const rate = (pct / gone) * 60
  const runOutIn = rate > 0 ? ((100 - pct) / rate) * 60 : null
  // A minute's slack, so "100% just as it resets" isn't reported as running out.
  const runsOut = runOutIn != null && runOutIn < remaining - 1
  const state = Math.abs(gap) <= evenWithin ? 'even' : gap > 0 ? 'over' : 'under'
  return {
    ...base,
    state,
    rate,
    runOutIn,
    runsOut,
    without: runsOut && runOutIn != null ? remaining - runOutIn : 0,
    budget,
  }
}

/** "2h 10m", "3d 4h", "45m", "now": the panel's own style. */
export function duration(minutes: number) {
  const m = Math.round(minutes)
  if (m <= 0) return 'now'
  const d = Math.floor(m / 1440)
  const h = Math.floor((m % 1440) / 60)
  const r = m % 60
  if (d > 0) return h > 0 ? `${d}d ${h}h` : `${d}d`
  if (h > 0) return r > 0 ? `${h}h ${r}m` : `${h}h`
  return `${r}m`
}

/**
 * Minutes from `now` until the next `time` ("15:40"), on `day` (0 Sunday … 6 Saturday)
 * if given. A time that has already passed means the next one.
 */
export function minutesUntil(time: string, now: Date, day?: number) {
  const [h = 0, m = 0] = time.split(':').map(Number)
  const at = new Date(now)
  at.setHours(h, m, 0, 0)
  if (day != null) at.setDate(at.getDate() + ((day - at.getDay() + 7) % 7))
  if (at.getTime() <= now.getTime()) at.setDate(at.getDate() + (day != null ? 7 : 1))
  return Math.round((at.getTime() - now.getTime()) / 60_000)
}

const clamp = (n: number, lo: number, hi: number) =>
  Number.isFinite(n) ? Math.min(Math.max(n, lo), hi) : lo
