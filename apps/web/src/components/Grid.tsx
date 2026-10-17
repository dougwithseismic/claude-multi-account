import {
  AppWindow,
  BellRing,
  EyeOff,
  type LucideIcon,
  ShieldCheck,
  SquareTerminal,
  Users,
} from 'lucide-react'
import { grid } from '../content'

const icons: Record<(typeof grid.items)[number]['icon'], LucideIcon> = {
  eye: EyeOff,
  team: Users,
  bell: BellRing,
  frame: AppWindow,
  terminal: SquareTerminal,
  shield: ShieldCheck,
}

export function Grid() {
  return (
    <section className="grid" aria-labelledby="grid-title">
      <div className="container grid__container">
        <h2 id="grid-title" className="t-h2 grid__title">
          {grid.title}
        </h2>
        <ul className="grid__list">
          {grid.items.map((item) => {
            const Icon = icons[item.icon]
            return (
              <li key={item.title} className="grid__item">
                <Icon aria-hidden="true" className="grid__icon" size={24} strokeWidth={1.75} />
                <h3 className="grid__name">{item.title}</h3>
                <p className="t-body">{item.body}</p>
              </li>
            )
          })}
        </ul>
      </div>
    </section>
  )
}
