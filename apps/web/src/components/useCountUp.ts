import { type RefObject, useEffect, useState } from 'react'
import { useInViewOnce } from './useScrollProgress'

/** Counts from 0 to `value` once the element comes into view. Measured on the reference:
 * a short pause, then 0.8s easing out to a gentle stop. Renders the final value before any script runs. */
export function useCountUp<T extends HTMLElement>(ref: RefObject<T | null>, value: number) {
  const seen = useInViewOnce(ref)
  const [shown, setShown] = useState(value)
  const [armed, setArmed] = useState(false)

  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
    setArmed(true)
    setShown(0)
  }, [])

  useEffect(() => {
    if (!armed || !seen) return
    let frame = 0
    const start = performance.now()
    const tick = (now: number) => {
      const t = Math.min(1, Math.max(0, now - start - 85) / 800)
      setShown(Math.round(value * (1 - (1 - t) ** 3.5)))
      if (t < 1) frame = requestAnimationFrame(tick)
    }
    frame = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame)
  }, [armed, seen, value])

  return shown
}
