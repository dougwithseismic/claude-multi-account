import { useEffect, useRef, useState } from 'react'
import type { TocItem } from '../lib/pages'

/** A page's HTML from the Markdown plugin, with its copy buttons wired up. */
export function Prose({ html, className }: { html: string; className?: string }) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const root = ref.current
    if (!root) return
    const timers = new Map<HTMLElement, number>()
    const click = (event: MouseEvent) => {
      const button = (event.target as HTMLElement).closest<HTMLElement>('[data-copy]')
      const code = button?.parentElement?.querySelector('code')
      if (!button || !code) return
      // A leading "$ " is the prompt, not part of the command.
      const text = (code.textContent ?? '').replace(/^\$ /gm, '').trimEnd()
      navigator.clipboard?.writeText(text).then(
        () => {
          button.textContent = 'Copied'
          button.dataset.copied = ''
          window.clearTimeout(timers.get(button))
          timers.set(
            button,
            window.setTimeout(() => {
              button.textContent = 'Copy'
              delete button.dataset.copied
            }, 1600),
          )
        },
        () => {
          button.textContent = 'Select and copy'
        },
      )
    }
    root.addEventListener('click', click)
    return () => {
      root.removeEventListener('click', click)
      for (const timer of timers.values()) window.clearTimeout(timer)
    }
  }, [])

  return (
    <div
      ref={ref}
      className={['prose', className].filter(Boolean).join(' ')}
      // The HTML is this repo's own Markdown, compiled at build time.
      dangerouslySetInnerHTML={{ __html: html }}
    />
  )
}

/** "On this page", with the heading in view marked. */
export function Toc({ items }: { items: TocItem[] }) {
  const [active, setActive] = useState<string | null>(null)

  useEffect(() => {
    const headings = items
      .map((item) => document.getElementById(item.id))
      .filter((el): el is HTMLElement => el != null)
    if (!headings.length) return
    const visible = new Set<string>()
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) visible.add(entry.target.id)
          else visible.delete(entry.target.id)
        }
        // The first heading in view, else the last one scrolled past.
        const first = headings.find((h) => visible.has(h.id))
        if (first) return setActive(first.id)
        const passed = headings.filter((h) => h.getBoundingClientRect().top < 0)
        setActive(passed.at(-1)?.id ?? null)
      },
      { rootMargin: '-80px 0px -60% 0px' },
    )
    for (const heading of headings) observer.observe(heading)
    return () => observer.disconnect()
  }, [items])

  if (items.length < 2) return null
  return (
    <nav className="toc" aria-label="On this page">
      <p className="toc__title">On this page</p>
      <ul>
        {items.map((item) => (
          <li key={item.id} data-depth={item.depth}>
            <a href={`#${item.id}`} aria-current={active === item.id ? 'location' : undefined}>
              {item.text}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  )
}
