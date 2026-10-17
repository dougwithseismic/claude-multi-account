import { useEffect, useState } from 'react'
import { nav } from '../content'
import { Logo } from './Logo'
import { Button, external } from './ui'

export function Nav() {
  const [open, setOpen] = useState(false)
  const [scrolled, setScrolled] = useState(false)

  // On phones the bar stays fixed, and gets a black backing once the hero has scrolled
  // past, as on the reference.
  useEffect(() => {
    const hero = document.querySelector('main > section')
    const check = () => setScrolled(window.scrollY >= (hero?.clientHeight ?? 0) - 1)
    check()
    window.addEventListener('scroll', check, { passive: true })
    window.addEventListener('resize', check)
    return () => {
      window.removeEventListener('scroll', check)
      window.removeEventListener('resize', check)
    }
  }, [])

  useEffect(() => {
    if (!open) return
    const close = (event: KeyboardEvent) => event.key === 'Escape' && setOpen(false)
    window.addEventListener('keydown', close)
    document.documentElement.style.overflow = 'hidden'
    return () => {
      window.removeEventListener('keydown', close)
      document.documentElement.style.overflow = ''
    }
  }, [open])

  return (
    <header
      className={['nav', open && 'is-open', scrolled && 'is-scrolled'].filter(Boolean).join(' ')}
    >
      <div className="nav__backing" aria-hidden="true" />
      <nav className="nav__bar container" aria-label="Main">
        <Logo />
        <ul className="nav__links">
          {nav.links.map((link) => (
            <li key={link.label}>
              <a className="nav__link" href={link.href} {...external(link)}>
                {link.label}
              </a>
            </li>
          ))}
        </ul>
        <Button link={nav.cta} variant="glass" size="sm" className="nav__cta" />
        <button
          type="button"
          className="nav__burger"
          aria-expanded={open}
          aria-controls="mobile-menu"
          aria-label={open ? 'Close menu' : 'Open menu'}
          onClick={() => setOpen(!open)}
        >
          <span />
          <span />
          <span />
        </button>
      </nav>
      <div id="mobile-menu" className="nav__sheet" inert={!open}>
        <ul className="nav__sheet-links">
          {nav.links.map((link, i) => (
            <li key={link.label} style={{ transitionDelay: `${0.05 * i}s` }}>
              <a href={link.href} {...external(link)} onClick={() => setOpen(false)}>
                {link.label}
              </a>
            </li>
          ))}
        </ul>
        <Button link={nav.cta} variant="glass" size="block" />
      </div>
    </header>
  )
}
