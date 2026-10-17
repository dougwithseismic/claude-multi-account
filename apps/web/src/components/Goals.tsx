import { useEffect, useRef, useState } from 'react'
import { goals } from '../content'

/** The PRD's goals, one at a time. Each bar fills over six seconds and moves on to the next;
 * it pauses off screen, under the pointer or keyboard focus, and doesn't move for reduced motion. */
export function Goals() {
  const section = useRef<HTMLElement>(null)
  const [active, setActive] = useState(0)
  const [cycled, setCycled] = useState(false)
  const [inView, setInView] = useState(false)
  const [still, setStill] = useState(true)

  useEffect(() => {
    const el = section.current
    if (!el) return
    const query = matchMedia('(prefers-reduced-motion: reduce)')
    const sync = () => setStill(query.matches)
    sync()
    query.addEventListener('change', sync)
    const observer = new IntersectionObserver((entries) =>
      setInView(entries.some((entry) => entry.isIntersecting)),
    )
    observer.observe(el)
    return () => {
      query.removeEventListener('change', sync)
      observer.disconnect()
    }
  }, [])

  const show = (index: number) => {
    setActive(index)
    setCycled(true)
  }

  return (
    <section
      ref={section}
      className={[
        'goals',
        cycled && 'has-cycled',
        inView && !still && 'is-playing',
        still && 'is-still',
      ]
        .filter(Boolean)
        .join(' ')}
      aria-roledescription="carousel"
      aria-label="The project’s goals"
    >
      <div className="container goals__container">
        <div className="goals__stage">
          {goals.map((goal, i) => (
            <figure
              key={goal.role}
              className="goals__slide"
              data-active={i === active ? '' : undefined}
              aria-hidden={i !== active}
            >
              <blockquote className="t-quote goals__quote">
                <p>{goal.quote}</p>
              </blockquote>
              <figcaption className="goals__author">
                <span className="goals__avatar" aria-hidden="true">
                  {goal.initials}
                </span>
                <span className="goals__profile">
                  <span className="goals__name">{goal.name}</span>
                  <span className="goals__role">{goal.role}</span>
                </span>
              </figcaption>
            </figure>
          ))}
        </div>
        <div className="goals__bars">
          {goals.map((goal, i) => (
            <button
              key={goal.role}
              type="button"
              className="goals__slot"
              aria-label={`Goal ${i + 1} of ${goals.length}`}
              aria-current={i === active ? 'true' : undefined}
              onClick={() => show(i)}
            >
              <span className="goals__track">
                {i === active && (
                  <span
                    className="goals__fill"
                    onAnimationEnd={() => {
                      if (!still) show((active + 1) % goals.length)
                    }}
                  />
                )}
              </span>
            </button>
          ))}
        </div>
      </div>
    </section>
  )
}
