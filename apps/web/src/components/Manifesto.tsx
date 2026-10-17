import { type CSSProperties, useCallback, useRef } from 'react'
import { manifesto } from '../content'
import { clamp01, useScrollFrame } from './useScrollProgress'

/** Inline glyphs between the words: original art, drawn for the page. */
function Glyph({ icon }: { icon: 'rings' | 'window' | 'notch' }) {
  if (icon === 'rings') {
    return (
      <svg viewBox="0 0 36 36" aria-hidden="true">
        <circle
          cx="18"
          cy="18"
          r="14.5"
          fill="none"
          stroke="currentColor"
          strokeOpacity=".3"
          strokeWidth="4"
        />
        <circle
          cx="18"
          cy="18"
          r="14.5"
          fill="none"
          stroke="currentColor"
          strokeWidth="4"
          strokeLinecap="round"
          strokeDasharray="56 91"
          transform="rotate(-90 18 18)"
        />
        <circle
          cx="18"
          cy="18"
          r="7"
          fill="none"
          stroke="currentColor"
          strokeOpacity=".3"
          strokeWidth="3.4"
        />
        <circle
          cx="18"
          cy="18"
          r="7"
          fill="none"
          stroke="currentColor"
          strokeWidth="3.4"
          strokeLinecap="round"
          strokeDasharray="30 44"
          transform="rotate(-90 18 18)"
        />
      </svg>
    )
  }
  if (icon === 'window') {
    return (
      <svg viewBox="0 0 36 36" aria-hidden="true">
        <rect
          x="2.5"
          y="5"
          width="31"
          height="26"
          rx="6"
          fill="none"
          stroke="currentColor"
          strokeWidth="3.2"
        />
        <path d="M2.5 13h31" stroke="currentColor" strokeWidth="3.2" />
        <circle cx="8" cy="9" r="1.6" fill="currentColor" />
        <circle cx="13" cy="9" r="1.6" fill="currentColor" />
        <rect x="8" y="18" width="13" height="3.2" rx="1.6" fill="currentColor" />
        <rect x="8" y="24" width="19" height="3.2" rx="1.6" fill="currentColor" opacity=".5" />
      </svg>
    )
  }
  return (
    <svg viewBox="0 0 36 36" aria-hidden="true">
      <path d="M2 8.5h32" stroke="currentColor" strokeWidth="3.2" strokeLinecap="round" />
      <path d="M11 8.5h14v4.5a4 4 0 0 1-4 4h-6a4 4 0 0 1-4-4z" fill="currentColor" />
      <circle cx="29" cy="25" r="5.5" fill="none" stroke="currentColor" strokeWidth="3" />
      <circle
        cx="17"
        cy="25"
        r="5.5"
        fill="none"
        stroke="currentColor"
        strokeWidth="3"
        strokeOpacity=".45"
      />
      <circle
        cx="5"
        cy="25"
        r="5.5"
        fill="none"
        stroke="currentColor"
        strokeWidth="3"
        strokeOpacity=".2"
      />
    </svg>
  )
}

export function Manifesto() {
  const ref = useRef<HTMLDivElement>(null)
  // Measured on the reference: the words light up while the text's top travels from
  // 92% to 12% of the viewport height.
  const update = useCallback((rect: DOMRect, vh: number) => {
    ref.current?.style.setProperty('--p', String(clamp01((0.922 * vh - rect.top) / (0.8 * vh))))
  }, [])
  useScrollFrame(ref, update)

  let index = 0
  const total = manifesto
    .flat()
    .reduce<number>((sum, part) => sum + (typeof part === 'string' ? part.split(' ').length : 1), 0)

  return (
    <section className="manifesto" aria-label="Why it exists">
      <div ref={ref} className="manifesto__text" style={{ '--n': total } as CSSProperties}>
        {manifesto.map((paragraph) => (
          <p key={String(paragraph[0])} className="manifesto__p">
            {paragraph.map((part) => {
              if (typeof part !== 'string') {
                const i = index++
                return (
                  <span
                    key={`g${i}`}
                    className="manifesto__glyph"
                    style={{ '--i': i } as CSSProperties}
                  >
                    <Glyph icon={part.icon} />
                  </span>
                )
              }
              return part.split(' ').map((word) => {
                const i = index++
                return (
                  <span key={`w${i}`}>
                    <span className="manifesto__word" style={{ '--i': i } as CSSProperties}>
                      {word}
                    </span>{' '}
                  </span>
                )
              })
            })}
          </p>
        ))}
      </div>
    </section>
  )
}
