import { type CSSProperties, type ReactNode, useEffect, useRef, useState } from 'react'
import { alertOrange, type Copy, colors, type Letter, notch, sample } from './data'
import { Closed, Panel, Peek } from './Notch'

/** Scales a fixed stage to fit whatever box it sits in, centred. */
function useFit<T extends HTMLElement>(stage: { width: number; height: number }) {
  const ref = useRef<T>(null)
  const [fit, setFit] = useState({ scale: 1, x: 0, y: 0 })
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new ResizeObserver(() => {
      const scale = Math.min(el.clientWidth / stage.width, el.clientHeight / stage.height)
      setFit({
        scale,
        x: (el.clientWidth - stage.width * scale) / 2,
        y: (el.clientHeight - stage.height * scale) / 2,
      })
    })
    observer.observe(el)
    return () => observer.disconnect()
  }, [stage.width, stage.height])
  return [ref, fit] as const
}

export type SceneName = 'rings' | 'panel' | 'peek' | 'terminal' | 'profiles'
export type Tint = 'orange' | 'blue' | 'green' | 'purple'

/** A stand-in Claude window: one per account, the one in front outlined in its colour. */
function ClaudeWindow({
  letter,
  outlined = false,
  style,
}: {
  letter: Letter
  outlined?: boolean
  style?: CSSProperties
}) {
  return (
    <div
      className="sc-window"
      data-outlined={outlined ? '' : undefined}
      style={{ ...style, '--c': colors[letter] } as CSSProperties}
    >
      <div className="sc-window__bar">
        <span className="sc-window__lights">
          <i />
          <i />
          <i />
        </span>
        <span className="sc-window__title">Claude {letter}</span>
      </div>
      <div className="sc-window__chat">
        <span className="sc-window__msg sc-window__msg--me" />
        <span className="sc-window__msg" style={{ width: '82%' }} />
        <span className="sc-window__msg" style={{ width: '64%' }} />
      </div>
      <div className="sc-window__composer">Reply to Claude {letter}…</div>
    </div>
  )
}

/** The top of a screen. `notchLeft` puts the notch, not the whole shape, at the centre. */
function Screen({
  zoom,
  notchLeft,
  children,
}: {
  zoom: number
  notchLeft?: number
  children: ReactNode
}) {
  return (
    <div className="sc-screen">
      <div className="sc-menubar" style={{ height: 32 * zoom }} />
      <div
        className="sc-notch"
        style={{
          zoom,
          translate: notchLeft == null ? undefined : `${-(notchLeft + notch.width / 2)}px 0`,
        }}
      >
        {children}
      </div>
    </div>
  )
}

const nearLimit: Copy[] = sample.map((copy) =>
  copy.letter === 'A'
    ? {
        ...copy,
        windows: copy.windows.map((w) =>
          w.label === '5-hour' ? { ...w, used: 91, reset: 'resets in 47m', pace: 0.84 } : w,
        ),
      }
    : copy,
)

const bar = (used: number) => {
  const filled = Math.round(used / 10)
  return (
    <span className={used >= 90 ? 'sc-red' : used >= 70 ? 'sc-yellow' : 'sc-green'}>
      {'█'.repeat(filled)}
      {'░'.repeat(10 - filled)}
    </span>
  )
}

/** `claude-usage`, printing what it prints. */
function Terminal() {
  const pad = Math.max(...sample.flatMap((c) => c.windows.map((w) => w.label.length)))
  return (
    <div className="sc-term">
      <div className="sc-term__bar">
        <span className="sc-window__lights">
          <i />
          <i />
          <i />
        </span>
        <span className="sc-term__title">zsh</span>
      </div>
      <pre className="sc-term__body">
        <span className="sc-dim">$</span> claude-usage{'\n'}
        {sample.map((copy, i) => (
          <span key={copy.letter}>
            {i > 0 && '\n'}
            <b style={{ color: colors[copy.letter] }}>Claude {copy.letter}</b>
            {`  ·  ${copy.letter.toLowerCase()}@example.com\n`}
            {'   '}
            <b>{copy.plan}</b>
            <span className="sc-dim">{`   (login valid ${27 - i * 9}d more)`}</span>
            {'\n'}
            {copy.windows.map((w) => (
              <span key={w.label}>
                {`     ${w.label.padEnd(pad)}  `}
                {bar(w.used)}
                {`  ${String(w.used).padStart(3)}%`}
                {w.wait == null
                  ? `  ${w.reset} (${w.label === '5-hour' ? 'Sat 18:31' : 'Tue 09:00'})`
                  : ''}
                {'\n'}
              </span>
            ))}
          </span>
        ))}
        <span className="sc-caret" />
      </pre>
    </div>
  )
}

/** profiles.json with a fourth copy added, and its ring beside the notch. */
function Profiles() {
  const rows = [
    ['A', 'Claude A', '#2F7BF5', '1'],
    ['B', 'Claude B', '#F5822F', '2'],
    ['C', 'Claude C', '#2FB36B', '3'],
    ['D', 'Claude D', '#B04FD6', '4'],
  ] as const
  return (
    <div className="sc-editor">
      <div className="sc-term__bar">
        <span className="sc-window__lights">
          <i />
          <i />
          <i />
        </span>
        <span className="sc-term__title">~/.config/claude-multi-account/profiles.json</span>
      </div>
      <pre className="sc-term__body">
        {'['}
        {rows.map(([letter, label, color, key], i) => (
          <span key={letter} className={letter === 'D' ? 'sc-line sc-added' : 'sc-line'}>
            {'  { '}
            <span className="sc-key">"letter"</span>: <span className="sc-str">"{letter}"</span>,{' '}
            <span className="sc-key">"label"</span>: <span className="sc-str">"{label}"</span>,
            {'\n'}
            {'    '}
            <span className="sc-key">"color"</span>:{' '}
            <i className="sc-swatch" style={{ background: color }} />
            <span className="sc-str">"{color}"</span>, <span className="sc-key">"hotkey"</span>:{' '}
            <span className="sc-str">"{key}"</span>
            {i < rows.length - 1 ? ' },' : ' }'}
          </span>
        ))}
        {']'}
      </pre>
    </div>
  )
}

const withD: Copy[] = [
  ...sample,
  {
    letter: 'D',
    plan: 'Pro',
    windows: [{ label: '5-hour', used: 4, reset: 'resets in 4h 52m', pace: 0.03 }],
  },
]

const scenes: Record<SceneName, () => ReactNode> = {
  rings: () => (
    <>
      <Screen zoom={1.6} notchLeft={notch.flare}>
        <Closed copies={sample} current="A" />
      </Screen>
      <ClaudeWindow letter="C" style={{ left: 64, top: 160 }} />
      <ClaudeWindow letter="B" style={{ left: 132, top: 218 }} />
      <ClaudeWindow letter="A" outlined style={{ left: 200, top: 276 }} />
    </>
  ),
  panel: () => (
    <Screen zoom={1.2}>
      <Panel copies={sample} current="A" />
    </Screen>
  ),
  peek: () => (
    <>
      <Screen zoom={1.45}>
        <Peek
          copies={nearLimit}
          current="A"
          letter="A"
          title="Claude A · 5-hour at 91%"
          trailing={
            <span
              style={{ color: alertOrange, display: 'inline-flex', alignItems: 'center', gap: 5 }}
            >
              <svg viewBox="0 0 12 12" aria-hidden="true">
                <path d="M6 1 11.5 11H.5Z" fill="currentColor" />
                <path d="M6 4.6v3M6 9.2v.1" stroke="#000" strokeWidth="1.3" strokeLinecap="round" />
              </svg>
              resets in 47m · 16:25
            </span>
          }
        />
      </Screen>
      <ClaudeWindow letter="B" style={{ left: 92, top: 236 }} />
      <ClaudeWindow letter="A" outlined style={{ left: 176, top: 290 }} />
    </>
  ),
  terminal: () => <Terminal />,
  profiles: () => (
    <>
      <Screen zoom={1.3} notchLeft={notch.flare}>
        <Closed copies={withD} current="D" />
      </Screen>
      <Profiles />
    </>
  ),
}

const stages: Record<SceneName, { width: number; height: number }> = {
  rings: { width: 586, height: 564 },
  panel: { width: 586, height: 564 },
  peek: { width: 586, height: 564 },
  terminal: { width: 564, height: 564 },
  profiles: { width: 564, height: 564 },
}

/** A product scene on its tinted wallpaper, scaled to its box. */
export function Scene({
  name,
  tint,
  shown,
  className,
  style,
}: {
  name: SceneName
  tint: Tint
  shown: boolean
  className?: string
  style?: CSSProperties
}) {
  const [ref, fit] = useFit<HTMLDivElement>(stages[name])
  return (
    <div
      ref={ref}
      className={['scene', `scene--${tint}`, shown && 'is-shown', className]
        .filter(Boolean)
        .join(' ')}
      style={style}
      aria-hidden="true"
    >
      <div
        className="scene__stage"
        style={{
          ...stages[name],
          transform: `translate(${fit.x}px, ${fit.y}px) scale(${fit.scale})`,
        }}
      >
        {scenes[name]()}
      </div>
    </div>
  )
}
