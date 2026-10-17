import { type MouseEvent, useLayoutEffect, useRef, useState } from 'react'
import { faq } from '../content'

/** The reference's height spring, sampled frame by frame: 1.6% over, settled in 0.32s. */
const spring =
  'linear(0, 0.061 5.3%, 0.235 10.6%, 0.449 15.6%, 0.64 20.9%, 0.779 26.3%, 0.884 31.6%, 0.948 36.6%, 0.987 41.9%, 1.007 47.2%, 1.015 52.2%, 1.016 57.5%, 1.013 62.5%, 1.011 67.8%, 1.007 73.1%, 1.004 78.4%, 1.003 83.4%, 1.0013 88.8%, 1)'

/** One question open at a time. Native `<details name>` does the work without JavaScript;
 * with it, each item's height runs on the spring as it opens or closes. */
export function Faq() {
  const list = useRef<HTMLDivElement>(null)
  const before = useRef<number[] | null>(null)
  const [open, setOpen] = useState<number | null>(null)

  const items = () => [...(list.current?.querySelectorAll<HTMLElement>('.faq__item') ?? [])]

  const toggle = (event: MouseEvent, index: number) => {
    event.preventDefault()
    before.current = items().map((item) => item.getBoundingClientRect().height)
    setOpen((current) => (current === index ? null : index))
  }

  // After each change of `open`: animate every item from its old height to its new one.
  useLayoutEffect(() => {
    const from = before.current
    before.current = null
    if (!from || matchMedia('(prefers-reduced-motion: reduce)').matches) return
    items().forEach((item, i) => {
      const to = item.getBoundingClientRect().height
      const start = from[i] ?? to
      if (Math.abs(to - start) < 0.5) return
      item.animate([{ height: `${start}px` }, { height: `${to}px` }], {
        duration: 320,
        easing: spring,
      })
    })
  }, [open])

  return (
    <section className="faq" id="faq" aria-labelledby="faq-title">
      <div className="container faq__container">
        <h2 id="faq-title" className="t-h2 faq__title">
          {faq.title}
        </h2>
        <div ref={list} className="faq__list">
          {faq.items.map((item, i) => (
            <details key={item.q} className="faq__item" name="faq" open={open === i}>
              <summary className="faq__q" onClick={(event) => toggle(event, i)}>
                <span>{item.q}</span>
                <svg className="faq__icon" viewBox="0 0 14 14" aria-hidden="true">
                  <path d="M7 1v12M1 7h12" />
                </svg>
              </summary>
              <p className="t-body faq__a">{item.a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  )
}
