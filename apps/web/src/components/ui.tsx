import type { CSSProperties, ReactNode } from 'react'
import type { Link } from '../content'

type ButtonProps = {
  link: Link
  variant?: 'primary' | 'glass' | 'outline'
  size?: 'md' | 'sm' | 'block'
  className?: string
  tabIndex?: number
}

export function Button({
  link,
  variant = 'primary',
  size = 'md',
  className,
  tabIndex,
}: ButtonProps) {
  const classes = ['btn', `btn--${variant}`, size !== 'md' && `btn--${size}`, className]
    .filter(Boolean)
    .join(' ')
  return (
    <a className={classes} href={link.href} tabIndex={tabIndex} {...external(link)}>
      {link.label}
    </a>
  )
}

export function external(link: Link) {
  return link.external ? { target: '_blank', rel: 'noreferrer' } : {}
}

/** Splits "text with *one* serif word" into its plain and serif runs. */
export function parseSerif(text: string) {
  return text
    .split(/(\*[^*]+\*)/)
    .filter(Boolean)
    .map((part) =>
      part.startsWith('*')
        ? { serif: true, text: part.slice(1, -1) }
        : { serif: false, text: part },
    )
}

/** A heading with its *serif* word. */
export function Serif({ text }: { text: string }) {
  return (
    <>
      {parseSerif(text).map((run) =>
        run.serif ? (
          <span key={run.text} className="t-serif">
            {run.text}
          </span>
        ) : (
          run.text
        ),
      )}
    </>
  )
}

/** A heading set one word at a time, so each word can rise in on its own delay. */
export function Words({ text, className }: { text: string; className?: string }) {
  let index = 0
  return (
    <span className={className}>
      {parseSerif(text).flatMap((run) =>
        run.text
          .split(' ')
          .filter(Boolean)
          .map((word) => {
            const i = index++
            return (
              <span key={`${i}-${word}`}>
                <span
                  className={run.serif ? 'word t-serif' : 'word'}
                  style={{ '--i': i } as CSSProperties}
                >
                  {word}
                </span>{' '}
              </span>
            )
          }),
      )}
    </span>
  )
}

export function Section({
  id,
  className,
  children,
  label,
}: {
  id?: string
  className: string
  children: ReactNode
  label?: string
}) {
  return (
    <section id={id} className={className} aria-label={label}>
      {children}
    </section>
  )
}
