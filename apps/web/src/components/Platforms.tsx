import { AppWindow, Gauge, Laptop, Monitor, Users } from 'lucide-react'
import type { ReactNode } from 'react'
import { platforms } from '../content'

function NotchGlyph() {
  return (
    <svg width="22" height="16" viewBox="0 0 22 16" fill="none" aria-hidden="true">
      <rect x="1" y="1.5" width="20" height="13" rx="2.5" stroke="currentColor" strokeWidth="1.8" />
      <path d="M8 1.5h6v1.8a1.2 1.2 0 0 1-1.2 1.2H9.2A1.2 1.2 0 0 1 8 3.3z" fill="currentColor" />
    </svg>
  )
}

const icons: Record<(typeof platforms.items)[number]['icon'], ReactNode> = {
  app: <AppWindow size={20} strokeWidth={2} />,
  gauge: <Gauge size={20} strokeWidth={2} />,
  team: <Users size={20} strokeWidth={2} />,
  laptop: <Laptop size={20} strokeWidth={2} />,
  notch: <NotchGlyph />,
  display: <Monitor size={20} strokeWidth={2} />,
}

function Row({ hidden }: { hidden?: boolean }) {
  return (
    <ul className="platforms__row" aria-hidden={hidden}>
      {platforms.items.map((item) => (
        <li key={item.label} className="platforms__item">
          {icons[item.icon]}
          <span>{item.label}</span>
        </li>
      ))}
    </ul>
  )
}

export function Platforms() {
  return (
    <section className="platforms" aria-label="Works with">
      <div className="platforms__container">
        <p className="platforms__label">{platforms.label}</p>
        <div className="platforms__ticker">
          <div className="platforms__track">
            <Row />
            <Row hidden />
            <Row hidden />
            <Row hidden />
          </div>
        </div>
      </div>
    </section>
  )
}
