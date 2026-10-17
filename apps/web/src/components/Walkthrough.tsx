import { BellRing, CircleDot, PanelTopOpen } from 'lucide-react'
import { type CSSProperties, useCallback, useEffect, useRef, useState } from 'react'
import { walkthrough } from '../content'
import { Scene } from './notch/Scenes'
import { Button } from './ui'
import { clamp01, useInViewOnce, useScrollFrame } from './useScrollProgress'

const tags = { Collapsed: CircleDot, Open: PanelTopOpen, Peeks: BellRing }
const tints = { orange: 'var(--tint-orange)', blue: 'var(--tint-blue)', green: 'var(--tint-green)' }

/** On a phone each step carries its own scene, revealed as it comes into view. */
function InlineScene({ item }: { item: (typeof walkthrough)[number] }) {
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInViewOnce(ref)
  return (
    <div ref={ref} className="walk__inline">
      <Scene name={item.scene} tint={item.tint} shown={seen} />
    </div>
  )
}

export function Walkthrough() {
  const container = useRef<HTMLDivElement>(null)
  const titles = useRef<Array<HTMLDivElement | null>>([])
  const media = useRef<HTMLDivElement>(null)
  const seen = useInViewOnce(media)
  const current = useRef(0)
  const [active, setActive] = useState(0)
  const [leaving, setLeaving] = useState<number | null>(null)
  const [armed, setArmed] = useState(false)

  useEffect(() => {
    if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) setArmed(true)
  }, [])

  // Measured on the reference: each later title fades in as its top rises from 93.6% to 56%
  // of the viewport; only the first fades out, from 7.8% to -31.4%. The scene swaps as the
  // next title's top passes 49%.
  const update = useCallback((_rect: DOMRect, vh: number) => {
    const sideBySide = window.innerWidth >= 810
    let next = 0
    titles.current.forEach((el, i) => {
      if (!el) return
      if (!sideBySide) {
        el.style.opacity = ''
        return
      }
      const top = el.getBoundingClientRect().top / vh
      const fadeIn = i === 0 ? 1 : clamp01((0.936 - top) / 0.376)
      const fadeOut = i === 0 ? clamp01((top + 0.314) / 0.392) : 1
      el.style.opacity = String(Math.min(fadeIn, fadeOut))
      if (i > 0 && top < 0.49) next = i
    })
    if (next !== current.current) {
      setLeaving(current.current)
      current.current = next
      setActive(next)
    }
  }, [])
  useScrollFrame(container, update)

  return (
    <section
      className="walk"
      id="how-it-works"
      aria-label="How it works"
      data-armed={armed ? '' : undefined}
    >
      <div className="container walk__container" ref={container}>
        <div className="walk__content">
          {walkthrough.map((item, i) => {
            const Icon = tags[item.tag]
            return (
              <div
                key={item.id}
                id={item.id}
                className="walk__item"
                ref={(el) => {
                  titles.current[i] = el
                }}
              >
                <InlineScene item={item} />
                <div className="walk__text">
                  <div className="walk__head">
                    <p
                      className="walk__pill"
                      style={{ '--tint': tints[item.tint] } as CSSProperties}
                    >
                      <Icon size={16} strokeWidth={2} aria-hidden="true" />
                      {item.tag}
                    </p>
                    <div className="walk__copy">
                      <h2 className="t-h2">{item.title}</h2>
                      <p className="t-lead">{item.body}</p>
                    </div>
                  </div>
                  <Button link={item.cta} variant="glass" className="walk__btn" />
                </div>
              </div>
            )
          })}
        </div>
        <div className="walk__media" ref={media}>
          {walkthrough.map((item, i) => (
            <Scene
              key={item.id}
              name={item.scene}
              tint={item.tint}
              shown={seen && (i === active || i === leaving)}
              className={
                i === active
                  ? 'walk__scene is-active'
                  : i === leaving
                    ? 'walk__scene is-leaving'
                    : 'walk__scene'
              }
            />
          ))}
        </div>
      </div>
    </section>
  )
}
