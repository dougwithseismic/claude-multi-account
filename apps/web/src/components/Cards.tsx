import { useEffect, useRef, useState } from 'react'
import { cards } from '../content'
import { useInViewOnce } from './useScrollProgress'

/** A rounded rectangle as path data, so each icon is one continuous stroke to draw on. */
function rect(x: number, y: number, w: number, h: number, r: number) {
  return `M${x + r} ${y}H${x + w - r}A${r} ${r} 0 0 1 ${x + w} ${y + r}V${y + h - r}A${r} ${r} 0 0 1 ${x + w - r} ${y + h}H${x + r}A${r} ${r} 0 0 1 ${x} ${y + h - r}V${y + r}A${r} ${r} 0 0 1 ${x + r} ${y}Z`
}

/** Original line art, drawn in a 96 box inside the 114 frame. */
const art: Record<(typeof cards.items)[number]['art'], string> = {
  // Three copies of Claude, one behind the other.
  rings: [rect(36, 0, 60, 46, 8), rect(18, 18, 60, 46, 8), rect(0, 36, 60, 46, 8), 'M0 50H60'].join(
    '',
  ),
  // ⌥ and 1 as two keycaps.
  keys: [
    rect(0, 20, 44, 56, 10),
    rect(5, 24, 34, 40, 7),
    'M12 37H18L27 51H33M25 37H33',
    rect(52, 20, 44, 56, 10),
    rect(57, 24, 34, 40, 7),
    'M70 40L75 36V52M70 52H80',
  ].join(''),
  // A link curving down into the window it belongs to.
  links: [rect(32, 48, 64, 48, 8), 'M32 60H96', 'M0 4C40 4 64 14 64 40', 'M56 32L64 40L72 32'].join(
    '',
  ),
}

/** Draws the stroke on over 2s the first time the cards come into view. */
function CardArt({ name, draw }: { name: keyof typeof art; draw: 'rest' | 'armed' | 'drawn' }) {
  return (
    <svg className="card__art" viewBox="0 0 114 114" aria-hidden="true" data-draw={draw}>
      <path d={art[name]} transform="translate(9 9)" pathLength={1} />
    </svg>
  )
}

export function Cards() {
  const row = useRef<HTMLDivElement>(null)
  const seen = useInViewOnce(row)
  // Rendered drawn, so the art shows without JavaScript; hidden only once the script runs.
  const [draw, setDraw] = useState<'rest' | 'armed' | 'drawn'>('rest')

  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
    setDraw((state) => (state === 'rest' ? 'armed' : state))
  }, [])

  useEffect(() => {
    if (!seen || draw !== 'armed') return
    const frame = requestAnimationFrame(() => setDraw('drawn'))
    return () => cancelAnimationFrame(frame)
  }, [seen, draw])

  return (
    <section className="cards" id="features" aria-labelledby="cards-title">
      <div className="container cards__container">
        <h2 id="cards-title" className="t-h2 cards__title">
          {cards.title}
        </h2>
        <div className="cards__row" ref={row}>
          {cards.items.map((item) => (
            <a key={item.title} className="card" href={item.href}>
              <div className="card__body">
                <CardArt name={item.art} draw={draw} />
                <div className="card__text">
                  <h3 className="t-title">{item.title}</h3>
                  <p className="t-body">{item.body}</p>
                </div>
              </div>
              <span className="btn btn--outline card__btn">See how</span>
            </a>
          ))}
        </div>
      </div>
    </section>
  )
}
