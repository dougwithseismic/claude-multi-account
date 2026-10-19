import assert from 'node:assert/strict'
import { test } from 'node:test'
import { duration, minutesUntil, pace, windows } from './pace.ts'

const fiveHour = windows.fiveHour.minutes

test('60% used with 2 hours left of 5 is an even pace that lasts until the reset', () => {
  const p = pace({ used: 60, length: fiveHour, left: 120 })
  assert.equal(p.state, 'even')
  assert.equal(p.elapsed, 0.6)
  assert.equal(Math.round(p.runOutIn ?? 0), 120)
  assert.equal(p.runsOut, false)
  assert.equal(p.without, 0)
  assert.equal(Math.round(p.budget), 20)
})

test('using faster than even runs out before the reset', () => {
  // 80% in 2 hours is 40% an hour, so 100% in 30 more minutes, 2.5 hours early.
  const p = pace({ used: 80, length: fiveHour, left: 180 })
  assert.equal(p.state, 'over')
  assert.equal(Math.round(p.gap), 40)
  assert.equal(p.runsOut, true)
  assert.equal(Math.round(p.runOutIn ?? 0), 30)
  assert.equal(Math.round(p.without), 150)
})

test('using slower than even never gets to 100% before the reset', () => {
  const p = pace({ used: 20, length: fiveHour, left: 60 })
  assert.equal(p.state, 'under')
  assert.equal(p.runsOut, false)
  assert.equal(Math.round(p.budget), 80)
})

test('0% used never runs out', () => {
  const p = pace({ used: 0, length: fiveHour, left: 100 })
  assert.equal(p.state, 'under')
  assert.equal(p.runOutIn, null)
  assert.equal(p.runsOut, false)
  assert.equal(p.budget, 60)
})

test('100% used is out until the reset', () => {
  const p = pace({ used: 100, length: fiveHour, left: 45 })
  assert.equal(p.state, 'out')
  assert.equal(p.runsOut, true)
  assert.equal(p.without, 45)
  assert.equal(p.budget, 0)
})

test('a reset time that has passed means the numbers are old', () => {
  assert.equal(pace({ used: 70, length: fiveHour, left: 0 }).state, 'reset')
  assert.equal(pace({ used: 70, length: fiveHour, left: -30 }).state, 'reset')
  assert.equal(pace({ used: 70, length: fiveHour, left: Number.NaN }).state, 'reset')
})

test('no time gone is too early to tell a rate', () => {
  const p = pace({ used: 5, length: fiveHour, left: fiveHour })
  assert.equal(p.state, 'early')
  assert.equal(p.runOutIn, null)
  assert.equal(p.elapsed, 0)
})

test('inputs out of range are clamped', () => {
  const p = pace({ used: 140, length: fiveHour, left: 9999 })
  assert.equal(p.state, 'out')
  assert.equal(p.left, fiveHour)
})

test('weekly windows work the same way', () => {
  // 3.5 days gone, 50% used: even.
  const p = pace({ used: 50, length: windows.weekly.minutes, left: 3.5 * 1440 })
  assert.equal(p.state, 'even')
  assert.equal(p.runsOut, false)
})

test('durations read like the panel', () => {
  assert.equal(duration(0), 'now')
  assert.equal(duration(45), '45m')
  assert.equal(duration(60), '1h')
  assert.equal(duration(130), '2h 10m')
  assert.equal(duration(1440 * 2 + 60 * 23 + 5), '2d 23h')
  assert.equal(duration(1440 * 3), '3d')
})

test('minutes until a clock time, today or tomorrow', () => {
  const now = new Date(2026, 5, 15, 14, 0)
  assert.equal(minutesUntil('15:40', now), 100)
  assert.equal(minutesUntil('13:00', now), 23 * 60)
  assert.equal(minutesUntil('14:00', now), 24 * 60)
})

// In June, so no daylight-saving change falls inside the week.
test('minutes until a day and time', () => {
  const monday = new Date(2026, 5, 15, 14, 0)
  assert.equal(monday.getDay(), 1)
  assert.equal(minutesUntil('09:00', monday, 4), 2 * 1440 + 19 * 60)
  assert.equal(minutesUntil('15:00', monday, 1), 60)
  assert.equal(minutesUntil('13:00', monday, 1), 7 * 1440 - 60)
})
