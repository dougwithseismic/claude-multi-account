import { type RefObject, useEffect, useState } from 'react'

/** Calls `update` with the element's viewport rect on every frame the page scrolls or
 * resizes, and once on mount. */
export function useScrollFrame<T extends HTMLElement>(
  ref: RefObject<T | null>,
  update: (rect: DOMRect, viewportHeight: number) => void,
) {
  useEffect(() => {
    const el = ref.current
    if (!el) return
    let frame = 0
    const run = () => {
      frame = 0
      update(el.getBoundingClientRect(), window.innerHeight)
    }
    const schedule = () => {
      if (!frame) frame = requestAnimationFrame(run)
    }
    run()
    window.addEventListener('scroll', schedule, { passive: true })
    window.addEventListener('resize', schedule)
    return () => {
      cancelAnimationFrame(frame)
      window.removeEventListener('scroll', schedule)
      window.removeEventListener('resize', schedule)
    }
  }, [ref, update])
}

export const clamp01 = (value: number) => Math.min(1, Math.max(0, value))

/** Flips to true the first time the element enters the viewport, and stays true. */
export function useInViewOnce<T extends HTMLElement>(ref: RefObject<T | null>) {
  const [seen, setSeen] = useState(false)
  useEffect(() => {
    const el = ref.current
    if (!el || seen) return
    const observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        setSeen(true)
        observer.disconnect()
      }
    })
    observer.observe(el)
    return () => observer.disconnect()
  }, [ref, seen])
  return seen
}
