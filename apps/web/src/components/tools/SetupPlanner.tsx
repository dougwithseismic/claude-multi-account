import { Minus, Plus } from 'lucide-react'
import { useEffect, useState } from 'react'
import { readHash, writeHash } from '../../lib/hash'
import { site } from '../../site'
import { CodeBlock } from '../CodeBlock'
import { colorOf, notch } from '../notch/data'
import { Badge, Ring, Surface } from '../notch/Notch'

type Profile = { label: string; color: string; hotkey: string }

const min = 2
const max = 9
const letterAt = (i: number) => String.fromCharCode(65 + i)
const fallback = (i: number): Profile => ({
  label: `Claude ${letterAt(i)}`,
  color: colorOf(letterAt(i)),
  hotkey: String(i + 1),
})
const hotkeys = ['', ...'123456789'.split(''), ...'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')]

// Made-up use for the preview's rings, so they don't all look the same.
const sampleUse = [
  [0.37, 0.62],
  [0.92, 0.4],
  [0.12, 0.3],
  [0.55, 0.8],
  [0.2, 0.15],
  [0.7, 0.5],
  [0.05, 0.9],
  [0.45, 0.25],
  [0.3, 0.7],
] as const

function fromHash(): Profile[] {
  const h = readHash()
  const n = Math.min(Math.max(Number(h.get('n')) || 3, min), max)
  let saved: Partial<Profile>[] = []
  try {
    const parsed = JSON.parse(h.get('p') ?? '[]')
    if (Array.isArray(parsed)) saved = parsed
  } catch {}
  return Array.from({ length: n }, (_, i) => {
    const base = fallback(i)
    const s = saved[i] ?? {}
    return {
      label: typeof s.label === 'string' ? s.label.slice(0, 40) : base.label,
      color: typeof s.color === 'string' && /^#[0-9a-f]{6}$/i.test(s.color) ? s.color : base.color,
      hotkey: typeof s.hotkey === 'string' && hotkeys.includes(s.hotkey) ? s.hotkey : base.hotkey,
    }
  })
}

const isDefault = (p: Profile, i: number) => {
  const base = fallback(i)
  return (
    p.label === base.label &&
    p.color.toLowerCase() === base.color.toLowerCase() &&
    p.hotkey === base.hotkey
  )
}

/** profiles.json as install.sh writes it: one profile to a line. */
function profilesJson(profiles: Profile[]) {
  const lines = profiles.map((p, i) => {
    const fields: [string, string][] = [
      ['letter', letterAt(i)],
      ['label', p.label.trim() || `Claude ${letterAt(i)}`],
      ['color', p.color.toUpperCase()],
    ]
    if (p.hotkey) fields.push(['hotkey', p.hotkey])
    return `  { ${fields.map(([k, v]) => `${JSON.stringify(k)}: ${JSON.stringify(v)}`).join(', ')} }`
  })
  return `[\n${lines.join(',\n')}\n]`
}

const clone =
  'git clone https://github.com/dougwithseismic/claude-multi-account.git ~/claude-multi-account'

export function SetupPlanner() {
  const [profiles, setProfiles] = useState<Profile[]>(() =>
    Array.from({ length: 3 }, (_, i) => fallback(i)),
  )
  const [restored, setRestored] = useState(false)

  useEffect(() => {
    setProfiles(fromHash())
    setRestored(true)
  }, [])

  useEffect(() => {
    if (!restored) return
    const h = new URLSearchParams({ n: String(profiles.length) })
    if (!profiles.every(isDefault)) h.set('p', JSON.stringify(profiles))
    writeHash(h)
  }, [profiles, restored])

  const count = profiles.length
  const resize = (n: number) =>
    setProfiles((current) =>
      Array.from({ length: Math.min(Math.max(n, min), max) }, (_, i) => current[i] ?? fallback(i)),
    )
  const update = (i: number, patch: Partial<Profile>) =>
    setProfiles((current) => current.map((p, j) => (j === i ? { ...p, ...patch } : p)))

  const custom = !profiles.every(isDefault)
  const json = profilesJson(profiles)
  const taken = new Map<string, number>()
  for (const p of profiles) if (p.hotkey) taken.set(p.hotkey, (taken.get(p.hotkey) ?? 0) + 1)
  const clashes = [...taken].filter(([, n]) => n > 1).map(([key]) => key)

  const ringsWidth = count * notch.ringSize + (count - 1) * notch.ringSpacing
  const width = notch.flare + notch.width + 8 + ringsWidth + 8 + notch.flare

  return (
    <div className="tool tool--wide">
      <section className="tool__panel tool__inputs" aria-label="Accounts">
        <div className="stepper">
          <span className="tool__label">Accounts</span>
          <div className="stepper__controls">
            <button
              type="button"
              className="stepper__button"
              onClick={() => resize(count - 1)}
              disabled={count <= min}
              aria-label="One fewer"
            >
              <Minus size={16} aria-hidden="true" />
            </button>
            <output className="stepper__value" aria-live="polite">
              {count}
            </output>
            <button
              type="button"
              className="stepper__button"
              onClick={() => resize(count + 1)}
              disabled={count >= max}
              aria-label="One more"
            >
              <Plus size={16} aria-hidden="true" />
            </button>
          </div>
        </div>

        <ol className="profiles">
          {profiles.map((p, i) => {
            const letter = letterAt(i)
            return (
              <li key={letter} className="profiles__row">
                <Badge letter={letter} color={p.color} size={26} />
                <label className="tool__field profiles__label">
                  <span className="tool__label">Name</span>
                  <input
                    className="tool__input"
                    value={p.label}
                    maxLength={40}
                    onChange={(event) => update(i, { label: event.target.value })}
                  />
                </label>
                <label className="tool__field profiles__color">
                  <span className="tool__label">Colour</span>
                  <input
                    className="tool__input tool__input--color"
                    type="color"
                    value={p.color}
                    onChange={(event) => update(i, { color: event.target.value })}
                  />
                </label>
                <label className="tool__field profiles__key">
                  <span className="tool__label">Hotkey</span>
                  <select
                    className="tool__input"
                    value={p.hotkey}
                    onChange={(event) => update(i, { hotkey: event.target.value })}
                  >
                    {hotkeys.map((key) => (
                      <option key={key || 'none'} value={key}>
                        {key ? `⌥⌘${key}` : 'None'}
                      </option>
                    ))}
                  </select>
                </label>
              </li>
            )
          })}
        </ol>
        {clashes.length > 0 && (
          <p className="tool__warning" role="alert">
            {clashes.map((key) => `⌥⌘${key}`).join(' and ')} is set for more than one account. Each
            hotkey can only open one.
          </p>
        )}
        <button
          type="button"
          className="tool__reset"
          onClick={() => setProfiles(Array.from({ length: count }, (_, i) => fallback(i)))}
          disabled={!custom}
        >
          Back to the defaults
        </button>
      </section>

      <section className="tool__panel tool__result" aria-label="Your setup">
        <div className="tool__preview">
          <Surface width={width} radius={10} className="nm-closed">
            <div className="nm-line" style={{ paddingLeft: notch.flare + notch.width + 8 }}>
              <span className="nm-rings">
                {profiles.map((p, i) => {
                  const [five, week] = sampleUse[i] ?? [0, 0]
                  return (
                    <span key={letterAt(i)} className="nm-rings__slot">
                      <Ring letter={letterAt(i)} color={p.color} fiveHour={five} weekly={week} />
                    </span>
                  )
                })}
              </span>
            </div>
          </Surface>
        </div>
        <p className="tool__body">
          {count} copies of Claude, A to {letterAt(count - 1)}. Each is a whole app, so with all of
          them open expect about {formatGb(count * 0.5)} to {formatGb(count)} of memory.
        </p>

        {custom ? (
          <>
            <h2 className="tool__step">1. Get the code</h2>
            <p className="tool__note">Skip this if Claude Notch is already installed.</p>
            <CodeBlock lang="bash" code={clone} />
            <h2 className="tool__step">2. Save your profiles</h2>
            <p className="tool__note">
              The installer never changes an existing profiles.json, so write yours before it runs.
              This replaces the file if you have one.
            </p>
            <CodeBlock
              lang="bash"
              code={`mkdir -p ~/.config/claude-multi-account && cat > ~/.config/claude-multi-account/profiles.json <<'EOF'\n${json}\nEOF`}
            />
            <h2 className="tool__step">3. Install</h2>
            <p className="tool__note">
              It sets up every copy the file lists. Already installed? Running it again adds any new
              copies and restarts Claude Notch with your names and colours.
            </p>
            <CodeBlock lang="bash" code="~/claude-multi-account/install.sh" />
          </>
        ) : (
          <>
            <h2 className="tool__step">Install</h2>
            <CodeBlock lang="bash" code={`${clone}\n~/claude-multi-account/install.sh ${count}`} />
            <p className="tool__note">
              Already installed? <code>~/claude-multi-account/install.sh {count}</code> adds the new
              copies and keeps everything else.
            </p>
            <h2 className="tool__step">The profiles.json it writes</h2>
            <CodeBlock lang="json" code={json} />
          </>
        )}
        <p className="tool__note">
          Needs macOS 26 and the Claude desktop app. <a href={site.install}>The install guide</a>{' '}
          covers the rest, and <a href={site.signIn}>signing in</a> to each new copy.
        </p>
      </section>
    </div>
  )
}

const formatGb = (gb: number) => `${Number.isInteger(gb) ? gb : gb.toFixed(1)} GB`
