import { type CSSProperties, useId, useState } from 'react'
import { duration, pace, windows } from '../../lib/pace'
import { colors, type Window } from '../notch/data'
import { Badge, Ring, Tag, WindowRow } from '../notch/Notch'

const length = windows.fiveHour.minutes
// The weekly window's own reset, fixed: the figure is about the 5-hour one.
const weeklyThrough = 0.55

export function Slider({
  label,
  value,
  onChange,
  max = 100,
  step = 1,
  format,
}: {
  label: string
  value: number
  onChange: (value: number) => void
  max?: number
  step?: number
  format: (value: number) => string
}) {
  const id = useId()
  return (
    <div className="slider">
      <label className="slider__label" htmlFor={id}>
        {label}
      </label>
      <output className="slider__value" htmlFor={id}>
        {format(value)}
      </output>
      <input
        id={id}
        className="slider__input"
        type="range"
        min={0}
        max={max}
        step={step}
        value={value}
        style={{ '--p': `${(value / max) * 100}%` } as CSSProperties}
        onChange={(event) => onChange(Number(event.target.value))}
      />
    </div>
  )
}

/** The 5-hour row as the panel draws it, from percent used and minutes left. */
export function fiveHourWindow(used: number, left: number): Window {
  if (used >= 100)
    return { label: '5-hour', used: 100, reset: `back in ${duration(left)}`, wait: left / length }
  return {
    label: '5-hour',
    used: Math.round(used),
    reset: `resets in ${duration(left)}`,
    pace: 1 - left / length,
  }
}

/**
 * A ring and a panel row the reader can drag, drawn with the site's mockup of the app.
 * `rings` explains the ring; `pace` explains the tick.
 */
export function UsageFigure({ variant = 'rings' }: { variant?: 'rings' | 'pace' }) {
  const [used, setUsed] = useState(variant === 'pace' ? 70 : 37)
  const [through, setThrough] = useState(variant === 'pace' ? 50 : 57)
  const [weekly, setWeekly] = useState(62)

  const left = Math.round(length * (1 - through / 100))
  const five = fiveHourWindow(used, left)
  const week: Window = {
    label: 'Weekly',
    used: weekly,
    reset: weekly >= 100 ? 'back in 3d 4h' : 'resets in 3d 4h',
    ...(weekly >= 100 ? { wait: 1 - weeklyThrough } : { pace: weeklyThrough }),
  }
  const p = pace({ used, length, left })

  return (
    <figure className="figure">
      <div className="figure__stage">
        {variant === 'rings' && (
          <div className="figure__ring">
            <Ring
              letter="A"
              fiveHour={five.wait ?? used / 100}
              out={five.wait != null}
              weekly={weekly / 100}
            />
          </div>
        )}
        <div className="figure__panel">
          <div className="nm-row">
            <Badge letter="A" />
            <div className="nm-row__main">
              <div className="nm-row__head">
                <span className="nm-row__name">Claude A</span>
                <Tag text="Max 5x" />
                <Tag text="current" letter="A" />
              </div>
              <div className="nm-row__windows">
                <WindowRow window={five} color={colors.A} />
                {variant === 'rings' && <WindowRow window={week} color={colors.A} />}
              </div>
            </div>
          </div>
        </div>
      </div>
      <div className="figure__controls">
        <Slider
          label="5-hour window used"
          value={used}
          onChange={setUsed}
          format={(v) => `${v}%`}
        />
        <Slider
          label="Time gone in the window"
          value={through}
          onChange={setThrough}
          max={99}
          format={(v) => (v === 0 ? '0m' : duration((length * v) / 100))}
        />
        {variant === 'rings' && (
          <Slider
            label="Weekly limit used"
            value={weekly}
            onChange={setWeekly}
            format={(v) => `${v}%`}
          />
        )}
      </div>
      <figcaption className="figure__caption" aria-live="polite">
        {variant === 'rings' ? ringsCaption(used, weekly, left) : paceCaption(p, used)}
      </figcaption>
    </figure>
  )
}

function ringsCaption(used: number, weekly: number, left: number) {
  const outer =
    used >= 100
      ? `The 5-hour window is used up, so the outer ring is red and empties as the wait runs down: back in ${duration(left)}.`
      : used >= 90
        ? `Past 90% of the 5-hour window, the outer ring and its bar turn red.`
        : `The outer ring is ${used}% of the way round: ${used}% of the 5-hour window used.`
  const inner =
    weekly >= 100
      ? ' The weekly limit is used up, so a red cross replaces the inner ring, whatever the outer ring says.'
      : ` The inner ring is the weekly limit, ${weekly}% used.`
  return outer + inner
}

function paceCaption(p: ReturnType<typeof pace>, used: number) {
  const through = `${Math.round(p.elapsed * 100)}% through the window`
  switch (p.state) {
    case 'out':
      return `At 100%: no more Claude on this account until it resets in ${duration(p.left)}.`
    case 'early':
      return 'The window has only just started, so there’s no pace to read yet.'
    case 'even':
      return `${used}% used, ${through}: an even pace, which lasts until the reset.`
    case 'under':
      return `${used}% used, ${through}: the bar is short of its tick, so at this rate it lasts until the reset with room to spare.`
    case 'over':
      return p.runsOut && p.runOutIn != null
        ? `${used}% used, ${through}: the bar is past its tick. At this rate it runs out in ${duration(p.runOutIn)}, ${duration(p.without)} before the reset.`
        : `${used}% used, ${through}: a little past the tick, but it still lasts until the reset.`
    default:
      return ''
  }
}
