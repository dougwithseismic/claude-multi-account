import { EyeOff, RotateCw, Settings } from 'lucide-react'
import type { CSSProperties, ReactNode } from 'react'
import {
  type Copy,
  colorOf,
  colors,
  type Letter,
  limitRed,
  notch,
  ringOf,
  type Window,
} from './data'

/** One double ring: the 5-hour window outside, the fullest weekly window inside. */
export function Ring({
  letter,
  fiveHour,
  out = false,
  weekly,
  dim = false,
  color: tint,
}: {
  letter: string
  fiveHour: number
  out?: boolean
  weekly: number
  dim?: boolean
  /** Instead of the letter's own colour. */
  color?: string
}) {
  const color = tint ?? colorOf(letter)
  const outer = out || fiveHour >= 0.9 ? limitRed : color
  return (
    <svg
      className="nm-ring"
      viewBox="0 0 16 16"
      aria-hidden="true"
      style={{ opacity: dim ? 0.45 : 1 }}
    >
      <circle cx="8" cy="8" r="7" stroke={color} strokeOpacity="0.28" strokeWidth="2.2" />
      <circle
        className="nm-ring__arc"
        cx="8"
        cy="8"
        r="7"
        stroke={outer}
        strokeWidth="2.2"
        pathLength={1}
        style={{ '--f': Math.min(fiveHour, 1) } as CSSProperties}
      />
      {weekly >= 1 ? (
        <path d="M6.1 6.1l3.8 3.8M9.9 6.1l-3.8 3.8" stroke={limitRed} strokeWidth="1.7" />
      ) : (
        <>
          <circle cx="8" cy="8" r="2.8" stroke={color} strokeOpacity="0.22" strokeWidth="1.6" />
          <circle
            className="nm-ring__arc"
            cx="8"
            cy="8"
            r="2.8"
            stroke={color}
            strokeOpacity="0.85"
            strokeWidth="1.6"
            pathLength={1}
            style={{ '--f': weekly } as CSSProperties}
          />
        </>
      )}
    </svg>
  )
}

/** The rings in a row, with a dot under the copy in front. */
export function Rings({ copies, current }: { copies: Copy[]; current?: Letter }) {
  return (
    <span className="nm-rings">
      {copies.map((copy) => (
        <span key={copy.letter} className="nm-rings__slot">
          <Ring letter={copy.letter} {...ringOf(copy)} />
          {current === copy.letter && (
            <span className="nm-rings__dot" style={{ background: colors[copy.letter] }} />
          )}
        </span>
      ))}
    </span>
  )
}

/** The notch's black shape: flared where it meets the top edge, rounded below. */
export function Surface({
  width,
  radius,
  className,
  children,
}: {
  width: number
  radius: number
  className?: string
  children: ReactNode
}) {
  return (
    <div
      className={['nm-surface', className].filter(Boolean).join(' ')}
      style={{ width, '--r': `${radius}px` } as CSSProperties}
    >
      {children}
    </div>
  )
}

const ringsWidth = (count: number) => count * notch.ringSize + (count - 1) * notch.ringSpacing

/** Closed: the notch, and the rings just right of it. */
export function Closed({
  copies,
  current,
  countdown,
}: {
  copies: Copy[]
  current?: Letter
  countdown?: ReactNode
}) {
  const width =
    notch.flare +
    notch.width +
    8 +
    ringsWidth(copies.length) +
    8 +
    notch.flare +
    (countdown ? 50 : 0)
  return (
    <Surface width={width} radius={10} className="nm-closed">
      <div className="nm-line" style={{ paddingLeft: notch.flare + notch.width + 8 }}>
        <Rings copies={copies} current={current} />
        {countdown}
      </div>
    </Surface>
  )
}

export function Badge({
  letter,
  size = 22,
  color,
}: {
  letter: string
  size?: number
  color?: string
}) {
  return (
    <span
      className="nm-badge"
      style={
        {
          '--c': color ?? colorOf(letter),
          width: size,
          height: size,
          fontSize: size * 0.5,
        } as CSSProperties
      }
    >
      {letter}
    </span>
  )
}

export function Tag({ text, letter }: { text: string; letter?: Letter }) {
  return (
    <span
      className="nm-tag"
      style={letter ? ({ '--c': colors[letter] } as CSSProperties) : undefined}
      data-colored={letter ? '' : undefined}
    >
      {text}
    </span>
  )
}

export function Bar({ window, color }: { window: Window; color: string }) {
  const waiting = window.wait != null
  const fill = waiting ? (window.wait ?? 0) : window.used / 100
  const tint = window.used >= 90 ? limitRed : color
  return (
    <span className="nm-bar">
      <span
        className="nm-bar__fill"
        data-waiting={waiting ? '' : undefined}
        style={{ '--f': Math.min(fill, 1), '--c': tint } as CSSProperties}
      />
      {window.pace != null && (
        <span className="nm-bar__tick" style={{ left: `calc(${window.pace * 100}% - 1px)` }} />
      )}
    </span>
  )
}

export function WindowRow({ window, color }: { window: Window; color: string }) {
  const full = window.used >= 100
  return (
    <div className="nm-window" data-full={full ? '' : undefined}>
      <span className="nm-window__label">{window.label}</span>
      <Bar window={window} color={color} />
      <span className="nm-window__pct">{window.used}%</span>
      <span className="nm-window__reset">{window.reset}</span>
    </div>
  )
}

function Row({ copy, current }: { copy: Copy; current: boolean }) {
  const color = colors[copy.letter]
  return (
    <div className="nm-row">
      <Badge letter={copy.letter} />
      <div className="nm-row__main">
        <div className="nm-row__head">
          <span className="nm-row__name">Claude {copy.letter}</span>
          {copy.plan && <Tag text={copy.plan} />}
          {current && <Tag text="current" letter={copy.letter} />}
        </div>
        <div className="nm-row__windows">
          {copy.windows.map((window) => (
            <WindowRow key={window.label} window={window} color={color} />
          ))}
        </div>
      </div>
    </div>
  )
}

/** Open: the panel grown out of the notch, one row per copy. */
export function Panel({ copies, current }: { copies: Copy[]; current: Letter }) {
  const notchLeft = (460 - notch.width) / 2
  return (
    <Surface width={460} radius={22} className="nm-panel">
      <div className="nm-top">
        <div className="nm-top__icons" style={{ width: notchLeft }}>
          {[Settings, EyeOff, RotateCw].map((Glyph) => (
            <span key={Glyph.displayName} className="nm-icon">
              <Glyph size={12.5} strokeWidth={2.4} aria-hidden="true" />
            </span>
          ))}
        </div>
        <div className="nm-line" style={{ paddingLeft: notch.width + 8 }}>
          <Rings copies={copies} current={current} />
        </div>
      </div>
      <div className="nm-panel__body">
        <div className="nm-rows">
          {copies.map((copy) => (
            <Row key={copy.letter} copy={copy} current={copy.letter === current} />
          ))}
        </div>
        <div className="nm-footer">
          <span>Updated just now · Links go to Claude {current}</span>
          <span>Hold ⌥ to show emails</span>
        </div>
      </div>
    </Surface>
  )
}

/** A peek: the notch widened, with a line under it. */
export function Peek({
  copies,
  current,
  letter,
  title,
  trailing,
}: {
  copies: Copy[]
  current?: Letter
  letter: Letter
  title: string
  trailing: ReactNode
}) {
  const wings = Math.max(92, 22 + ringsWidth(copies.length) + 8)
  return (
    <Surface width={notch.width + 2 * wings} radius={18} className="nm-peek">
      <div className="nm-line" style={{ paddingLeft: wings + notch.width + 8 }}>
        <Rings copies={copies} current={current} />
      </div>
      <div className="nm-peek__line">
        <Badge letter={letter} size={17} />
        <span className="nm-peek__title">{title}</span>
        <span className="nm-peek__trailing">{trailing}</span>
      </div>
    </Surface>
  )
}
