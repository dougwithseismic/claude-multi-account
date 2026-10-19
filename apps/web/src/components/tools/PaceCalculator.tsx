import { Link2 } from 'lucide-react'
import { type ReactNode, useEffect, useId, useState } from 'react'
import { readHash, writeHash } from '../../lib/hash'
import { duration, minutesUntil, type Pace, pace, type WindowKind, windows } from '../../lib/pace'
import { useCopy } from '../CodeBlock'
import { fiveHourWindow, Slider } from '../figures/UsageFigure'
import { colors, type Window } from '../notch/data'
import { WindowRow } from '../notch/Notch'

const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']

type Inputs = {
  kind: WindowKind
  used: number
  mode: 'in' | 'at'
  /** Minutes until the reset, for `in`. */
  inMinutes: number
  /** "15:40", for `at`. */
  time: string
  /** 0 Sunday … 6 Saturday, for `at` on a weekly window. */
  day: number
}

// The PRD's example: 60% used with 2 hours left of 5.
const defaults: Inputs = {
  kind: 'fiveHour',
  used: 60,
  mode: 'in',
  inMinutes: 120,
  time: '17:00',
  day: 4,
}

function fromHash(): Inputs {
  const h = readHash()
  const kind = h.get('w') === '7d' ? 'weekly' : 'fiveHour'
  const number = (key: string, fallback: number) => {
    const n = Number(h.get(key))
    return h.has(key) && Number.isFinite(n) ? n : fallback
  }
  const time = h.get('at')
  return {
    kind,
    used: Math.min(Math.max(number('used', defaults.used), 0), 100),
    mode: time && /^\d{1,2}:\d{2}$/.test(time) ? 'at' : 'in',
    inMinutes: number('in', kind === 'weekly' ? 3 * 1440 : defaults.inMinutes),
    time: time ?? defaults.time,
    day: Math.min(Math.max(Math.round(number('day', defaults.day)), 0), 6),
  }
}

function toHash(i: Inputs) {
  const h = new URLSearchParams({ w: i.kind === 'weekly' ? '7d' : '5h', used: String(i.used) })
  if (i.mode === 'in') h.set('in', String(i.inMinutes))
  else {
    h.set('at', i.time)
    if (i.kind === 'weekly') h.set('day', String(i.day))
  }
  return h
}

/** The time now, once the page is in a browser: the prerendered page has no "now". */
function useNow() {
  const [now, setNow] = useState<Date | null>(null)
  useEffect(() => {
    setNow(new Date())
    const timer = window.setInterval(() => setNow(new Date()), 30_000)
    return () => window.clearInterval(timer)
  }, [])
  return now
}

const clock = (at: Date, weekly: boolean) =>
  at.toLocaleString([], {
    ...(weekly ? { weekday: 'short' } : {}),
    hour: '2-digit',
    minute: '2-digit',
  })

export function PaceCalculator() {
  const [inputs, setInputs] = useState<Inputs>(defaults)
  const [restored, setRestored] = useState(false)
  const now = useNow()
  const { state: copied, copy } = useCopy()

  useEffect(() => {
    setInputs(fromHash())
    setRestored(true)
    const onHash = () => setInputs(fromHash())
    window.addEventListener('hashchange', onHash)
    return () => window.removeEventListener('hashchange', onHash)
  }, [])

  useEffect(() => {
    if (restored) writeHash(toHash(inputs))
  }, [inputs, restored])

  const set = (patch: Partial<Inputs>) => setInputs((current) => ({ ...current, ...patch }))
  const span = windows[inputs.kind]
  const weekly = inputs.kind === 'weekly'
  const left =
    inputs.mode === 'in'
      ? Math.min(inputs.inMinutes, span.minutes)
      : now
        ? Math.min(minutesUntil(inputs.time, now, weekly ? inputs.day : undefined), span.minutes)
        : null
  const result = left == null ? null : pace({ used: inputs.used, length: span.minutes, left })
  const at = (minutes: number) =>
    now ? clock(new Date(now.getTime() + minutes * 60_000), weekly) : null

  return (
    <div className="tool">
      <form className="tool__panel tool__inputs" onSubmit={(event) => event.preventDefault()}>
        <Segmented
          label="Window"
          value={inputs.kind}
          options={[
            ['fiveHour', '5-hour'],
            ['weekly', 'Weekly'],
          ]}
          onChange={(kind) =>
            set({
              kind,
              inMinutes: Math.min(inputs.inMinutes, windows[kind].minutes),
            })
          }
        />
        <Slider
          label="Used so far"
          value={inputs.used}
          onChange={(used) => set({ used })}
          format={(v) => `${v}%`}
        />
        <Segmented
          label="It resets"
          value={inputs.mode}
          options={[
            ['in', 'In'],
            ['at', 'At'],
          ]}
          onChange={(mode) => set({ mode })}
        />
        {inputs.mode === 'in' ? (
          <Duration
            minutes={inputs.inMinutes}
            max={span.minutes}
            withDays={weekly}
            onChange={(inMinutes) => set({ inMinutes })}
          />
        ) : (
          <div className="tool__row">
            {weekly && (
              <Field label="Day">
                <select
                  className="tool__input"
                  value={inputs.day}
                  onChange={(event) => set({ day: Number(event.target.value) })}
                >
                  {days.map((name, i) => (
                    <option key={name} value={i}>
                      {name}
                    </option>
                  ))}
                </select>
              </Field>
            )}
            <Field label="Time">
              <input
                className="tool__input"
                type="time"
                value={inputs.time}
                onChange={(event) => event.target.value && set({ time: event.target.value })}
              />
            </Field>
          </div>
        )}
        <p className="tool__hint">
          Claude shows both in Settings → Usage. Claude Notch shows them on every bar.
        </p>
      </form>

      <section className="tool__panel tool__result" aria-live="polite" aria-label="Result">
        {result ? (
          <Result result={result} used={inputs.used} weekly={weekly} at={at} />
        ) : (
          <p className="tool__verdict">Working out the time…</p>
        )}
        <button
          type="button"
          className="tool__share"
          onClick={() => copy(window.location.href)}
          data-copied={copied === 'copied' ? '' : undefined}
        >
          <Link2 size={15} aria-hidden="true" />
          {copied === 'copied' ? 'Link copied' : 'Copy a link to this result'}
        </button>
      </section>
    </div>
  )
}

function Result({
  result: p,
  used,
  weekly,
  at,
}: {
  result: Pace
  used: number
  weekly: boolean
  at: (minutes: number) => string | null
}) {
  const label = weekly ? 'Weekly' : '5-hour'
  const length = windows[weekly ? 'weekly' : 'fiveHour'].minutes
  const row: Window = weekly
    ? used >= 100
      ? { label, used: 100, reset: `back in ${duration(p.left)}`, wait: p.left / length }
      : { label, used: Math.round(used), reset: `resets in ${duration(p.left)}`, pace: p.elapsed }
    : fiveHourWindow(used, p.left)
  const when = (minutes: number) => at(minutes) ?? `in ${duration(minutes)}`

  const verdict = (() => {
    switch (p.state) {
      case 'reset':
        return {
          tone: 'neutral',
          title: 'This window has already reset',
          body: 'Check Claude for the new numbers.',
        }
      case 'out':
        return {
          tone: 'red',
          title: `Out until ${when(p.left)}`,
          body: `At 100%. It resets in ${duration(p.left)}.`,
        }
      case 'early':
        return {
          tone: 'neutral',
          title: 'Too early to tell',
          body: 'The window has only just started, so there’s no rate to go on yet.',
        }
      case 'even':
        return {
          tone: 'neutral',
          title: 'On an even pace',
          body: 'You’d reach 100% just as it resets.',
        }
      case 'under':
        return {
          tone: 'green',
          title: 'It lasts until the reset',
          body: `${Math.round(-p.gap)} points under an even pace.`,
        }
      default:
        return p.runsOut && p.runOutIn != null
          ? {
              tone: 'red',
              title: `You’d run out ${at(p.runOutIn) ? `at ${at(p.runOutIn)}` : `in ${duration(p.runOutIn)}`}`,
              body: `${duration(p.without)} before it resets, at the rate so far.`,
            }
          : { tone: 'neutral', title: 'It just about lasts', body: 'A little over an even pace.' }
    }
  })()

  const stats: [string, string, boolean?][] = [
    [
      'Through the window',
      `${Math.round(p.elapsed * 100)}%, ${duration(length - p.left)} of ${duration(length)}`,
    ],
  ]
  if (p.state !== 'reset' && p.state !== 'early' && p.state !== 'out') {
    stats.push([
      'Against an even pace',
      p.state === 'even'
        ? 'Even'
        : `${Math.round(Math.abs(p.gap))} points ${p.gap > 0 ? 'over' : 'under'}`,
    ])
    stats.push([
      '100% at the rate so far',
      p.runsOut && p.runOutIn != null
        ? [`in ${duration(p.runOutIn)}`, at(p.runOutIn)].filter(Boolean).join(', at ')
        : p.state === 'even'
          ? 'Just as it resets'
          : 'Not before the reset',
    ])
    if (p.runsOut) stats.push(['Without Claude before the reset', duration(p.without), true])
  }
  if (p.state === 'out') stats.push(['Without Claude', duration(p.left), true])
  if (p.state !== 'reset' && p.state !== 'out') {
    stats.push([
      'To last until the reset',
      weekly ? `${formatRate(p.budget * 24)} a day` : `${formatRate(p.budget)} an hour`,
    ])
  }

  return (
    <>
      <p className="tool__verdict" data-tone={verdict.tone}>
        {verdict.title}
      </p>
      <p className="tool__body">{verdict.body}</p>
      <div className="figure__panel tool__bar">
        <WindowRow window={row} color={colors.A} />
      </div>
      <dl className="tool__stats">
        {stats.map(([name, value, red]) => (
          <div key={name} className="tool__stat" data-red={red ? '' : undefined}>
            <dt>{name}</dt>
            <dd>{value}</dd>
          </div>
        ))}
      </dl>
    </>
  )
}

const formatRate = (percent: number) =>
  percent >= 10 ? `${Math.round(percent)}%` : `${percent.toFixed(1).replace(/\.0$/, '')}%`

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="tool__field">
      <span className="tool__label">{label}</span>
      {children}
    </label>
  )
}

export function Segmented<T extends string>({
  label,
  value,
  options,
  onChange,
}: {
  label: string
  value: T
  options: [T, string][]
  onChange: (value: T) => void
}) {
  const name = useId()
  return (
    <fieldset className="segmented">
      <legend className="tool__label">{label}</legend>
      <div className="segmented__options">
        {options.map(([option, text]) => (
          <label
            key={option}
            className="segmented__option"
            data-on={value === option ? '' : undefined}
          >
            <input
              type="radio"
              name={name}
              value={option}
              checked={value === option}
              onChange={() => onChange(option)}
            />
            {text}
          </label>
        ))}
      </div>
    </fieldset>
  )
}

function Duration({
  minutes,
  max,
  withDays,
  onChange,
}: {
  minutes: number
  max: number
  withDays: boolean
  onChange: (minutes: number) => void
}) {
  const d = withDays ? Math.floor(minutes / 1440) : 0
  const h = Math.floor((minutes - d * 1440) / 60)
  const m = Math.round(minutes % 60)
  const update = (next: { d?: number; h?: number; m?: number }) => {
    const total = (next.d ?? d) * 1440 + (next.h ?? h) * 60 + (next.m ?? m)
    onChange(Math.min(Math.max(total, 0), max))
  }
  const part = (name: string, value: number, top: number, key: 'd' | 'h' | 'm') => (
    <Field label={name}>
      <input
        className="tool__input"
        type="number"
        inputMode="numeric"
        min={0}
        max={top}
        value={value}
        onChange={(event) => update({ [key]: Math.max(0, Number(event.target.value) || 0) })}
      />
    </Field>
  )
  return (
    <div className="tool__row">
      {withDays && part('Days', d, 7, 'd')}
      {part('Hours', h, withDays ? 23 : 5, 'h')}
      {part('Minutes', m, 59, 'm')}
    </div>
  )
}
