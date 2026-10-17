import { ArrowDownToLine, Eye } from 'lucide-react'
import type { CSSProperties, ReactNode } from 'react'
import { type Copy, colors, type Letter } from './notch/data'
import { Badge, Bar, Closed, Ring, Rings, Tag } from './notch/Notch'

export type DetailArt =
  | 'hold'
  | 'tick'
  | 'cross'
  | 'countdown'
  | 'pill'
  | 'haptic'
  | 'login'
  | 'update'

const tints: Record<DetailArt, string> = {
  hold: 'blue',
  tick: 'orange',
  cross: 'green',
  countdown: 'purple',
  pill: 'orange',
  haptic: 'green',
  login: 'blue',
  update: 'purple',
}

/** Every copy out, C first back. */
const allOut: Copy[] = [
  { letter: 'A', windows: [{ label: '5-hour', used: 100, reset: '', wait: 0.55 }] },
  { letter: 'B', windows: [{ label: '5-hour', used: 100, reset: '', wait: 0.3 }] },
  { letter: 'C', windows: [{ label: '5-hour', used: 100, reset: '', wait: 0.06 }] },
]

const three: Copy[] = [
  {
    letter: 'A',
    windows: [
      { label: '5-hour', used: 37, reset: '' },
      { label: 'Weekly', used: 62, reset: '' },
    ],
  },
  {
    letter: 'B',
    windows: [
      { label: '5-hour', used: 64, reset: '' },
      { label: 'Weekly', used: 40, reset: '' },
    ],
  },
  {
    letter: 'C',
    windows: [
      { label: '5-hour', used: 12, reset: '' },
      { label: 'Weekly', used: 30, reset: '' },
    ],
  },
]

/** A mockup drawn at the app's sizes and scaled up, placed in the card by its top left. */
function Zoomed({
  zoom,
  style,
  children,
}: {
  zoom: number
  style: CSSProperties
  children: ReactNode
}) {
  return (
    <div className="da-place" style={style}>
      <div style={{ zoom }}>{children}</div>
    </div>
  )
}

function Switch() {
  return (
    <span className="da-switch">
      <i />
    </span>
  )
}

const arts: Record<DetailArt, () => ReactNode> = {
  // Holding ⌥ swaps each row's name for its login's email.
  hold: () => (
    <>
      <Zoomed zoom={1.15} style={{ left: 16, top: 54 }}>
        <div className="da-panel" style={{ width: 248 }}>
          <div className="nm-row">
            <Badge letter="A" />
            <div className="nm-row__main">
              <div className="nm-row__head">
                <span className="nm-row__name">you@example.com</span>
                <Tag text="Max 20x" />
              </div>
              <div className="da-row__bar">
                <span>5-hour</span>
                <Bar
                  window={{ label: '5-hour', used: 37, reset: '', pace: 0.57 }}
                  color={colors.A}
                />
              </div>
            </div>
          </div>
          <div className="da-footer">
            <Eye size={10} strokeWidth={2.4} aria-hidden="true" />
            Showing details
          </div>
        </div>
      </Zoomed>
      <span className="da-key" style={{ left: 192, top: 168 }}>
        <span className="da-key__glyph">⌥</span>
        <span className="da-key__name">option</span>
      </span>
    </>
  ),
  // The tick on each bar: past it, the window is going faster than an even pace.
  tick: () => (
    <Zoomed zoom={1.9} style={{ left: 24, top: 70 }}>
      <div className="da-panel da-bars" style={{ width: 142 }}>
        {[
          { label: '5-hour', used: 37, pace: 0.57 },
          { label: 'Weekly', used: 62, pace: 0.48 },
        ].map((w) => (
          <div key={w.label} className="da-bars__item">
            <div className="da-bars__head">
              <span>{w.label}</span>
              <b>{w.used}%</b>
            </div>
            <Bar window={{ ...w, reset: '' }} color={colors.A} />
          </div>
        ))}
      </div>
    </Zoomed>
  ),
  cross: () => (
    <span className="da-tile" style={{ left: 84, top: 64, width: 150, height: 150 }}>
      <Ring letter="B" fiveHour={0.64} weekly={1} />
    </span>
  ),
  // Every copy is out: the countdown points to the first one back.
  countdown: () => (
    <>
      <div className="da-menubar" style={{ height: 45 }} />
      <Zoomed zoom={1.4} style={{ left: -191, top: 0 }}>
        <Closed
          copies={allOut}
          countdown={
            <span className="da-back">
              <span style={{ color: colors.C }}>C</span>4:12
            </span>
          }
        />
      </Zoomed>
    </>
  ),
  // A display without a notch: a black pill, 168 × 24, with the rings and no dot.
  pill: () => (
    <div className="da-display" style={{ left: 29, top: 50 }}>
      <div className="da-display__screen">
        <div className="da-menubar" style={{ height: 18 }} />
        <Zoomed zoom={0.75} style={{ left: 56.5, top: 0 }}>
          <div className="nm-surface da-pill" style={{ '--r': '10px' } as CSSProperties}>
            <div className="nm-line">
              <Rings copies={three} />
            </div>
          </div>
        </Zoomed>
      </div>
      <span className="da-display__stand" />
    </div>
  ),
  haptic: () => (
    <div className="da-pad" style={{ left: 39, top: 66 }}>
      <span className="da-pad__touch">
        <i />
        <i />
        <i />
      </span>
    </div>
  ),
  login: () => (
    <Zoomed zoom={1.2} style={{ left: 16, top: 44 }}>
      <div className="da-panel da-settings" style={{ width: 238 }}>
        <span className="da-settings__title">General</span>
        <div className="da-settings__group">
          <div className="da-settings__row">
            <span className="da-settings__label">Open at login</span>
            <Switch />
          </div>
          <div className="da-settings__row">
            <span className="da-settings__label">Profiles</span>
            <span className="da-settings__pills">
              <span className="da-pill-button">Edit</span>
              <span className="da-pill-button">Reload</span>
            </span>
          </div>
        </div>
      </div>
    </Zoomed>
  ),
  // One Claude.app updates; every copy runs it once reopened.
  update: () => (
    <div className="da-update" style={{ left: 49, top: 40 }}>
      <span className="da-update__app">
        <ArrowDownToLine size={30} strokeWidth={2} aria-hidden="true" />
      </span>
      <svg className="da-update__lines" viewBox="0 0 220 64" aria-hidden="true">
        <path d="M110 0v20c0 12-76 12-76 26v18M110 0v64M110 0v20c0 12 76 12 76 26v18" />
      </svg>
      <span className="da-update__copies">
        {(['A', 'B', 'C'] as Letter[]).map((letter) => (
          <Badge key={letter} letter={letter} size={48} />
        ))}
      </span>
    </div>
  ),
}

/** The art behind a details card: the app's own pieces on a tinted wallpaper. */
export function DetailsArt({ art }: { art: DetailArt }) {
  return (
    <div className={`scene scene--${tints[art]} is-shown da`} aria-hidden="true">
      {arts[art]()}
    </div>
  )
}
