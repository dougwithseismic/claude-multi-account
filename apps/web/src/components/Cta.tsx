import { useEffect, useRef, useState } from 'react'
import { cta } from '../content'
import { Button, Serif } from './ui'

/** The last ask. The buttons rise in once they're in full view; without JavaScript they
 * simply show. */
export function Cta() {
  const buttons = useRef<HTMLDivElement>(null)
  const [reveal, setReveal] = useState<'rest' | 'armed' | 'shown'>('rest')

  useEffect(() => {
    const el = buttons.current
    if (!el) return
    setReveal('armed')
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          setReveal('shown')
          observer.disconnect()
        }
      },
      { threshold: 1 },
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  return (
    <section className="cta" aria-labelledby="cta-title">
      <div className="cta__art" aria-hidden="true">
        <div className="cta__ring cta__ring--a" />
        <div className="cta__ring cta__ring--b" />
        <div className="cta__ring cta__ring--c" />
      </div>
      <div className="container cta__container">
        <h2 id="cta-title" className="t-h2 cta__title">
          <Serif text={cta.title} />
        </h2>
        <div ref={buttons} className="buttons cta__buttons" data-reveal={reveal}>
          <Button link={cta.primary} />
          <Button link={cta.secondary} variant="glass" />
        </div>
      </div>
    </section>
  )
}
