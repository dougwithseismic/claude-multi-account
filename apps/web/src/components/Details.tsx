import { ChevronLeft, ChevronRight, Plus } from 'lucide-react'
import { type CSSProperties, useEffect, useRef, useState } from 'react'
import { details } from '../content'
import { DetailsArt } from './DetailsArt'

/** A card and the gap after it. */
const step = 318 + 16

/** A row of cards. On desktop the arrows slide it one card at a time; below that it scrolls. */
export function Details() {
  const wrapper = useRef<HTMLDivElement>(null)
  const track = useRef<HTMLUListElement>(null)
  const [index, setIndex] = useState(0)
  // How far the row can slide: until its last card is in full view.
  const [room, setRoom] = useState((details.items.length - 4) * step)

  useEffect(() => {
    const el = wrapper.current
    const row = track.current
    if (!el || !row) return
    const observer = new ResizeObserver(() =>
      setRoom(Math.max(0, row.scrollWidth - el.clientWidth)),
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  const last = Math.ceil(room / step)
  const current = Math.min(index, last)
  const offset = Math.min(current * step, room)

  return (
    <section className="details" aria-labelledby="details-title">
      <div className="container details__container">
        <div className="details__head">
          <h2 id="details-title" className="t-h2 details__title">
            {details.title}
          </h2>
          <div className="details__arrows">
            <button
              type="button"
              className="details__arrow"
              aria-label="Previous"
              disabled={current === 0}
              onClick={() => setIndex(Math.max(0, current - 1))}
            >
              <ChevronLeft size={24} strokeWidth={2.25} aria-hidden="true" />
            </button>
            <button
              type="button"
              className="details__arrow"
              aria-label="Next"
              disabled={current >= last}
              onClick={() => setIndex(Math.min(last, current + 1))}
            >
              <ChevronRight size={24} strokeWidth={2.25} aria-hidden="true" />
            </button>
          </div>
        </div>
        <div ref={wrapper} className="details__wrapper">
          <ul
            ref={track}
            className="details__track"
            style={{ '--x': `${-offset}px` } as CSSProperties}
          >
            {details.items.map((item) => (
              <li key={item.art} className="details__card">
                <DetailsArt art={item.art} />
                <span className="details__overlay" />
                <span className="details__plus" aria-hidden="true">
                  <Plus size={24} strokeWidth={1.75} />
                </span>
                <div className="details__text">
                  <h3 className="details__name">{item.title}</h3>
                  <p className="t-body">{item.body}</p>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  )
}
