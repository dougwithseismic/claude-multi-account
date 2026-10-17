import { Sparkle } from 'lucide-react'
import { hero } from '../content'
import { Button, Words } from './ui'

/** Original background art in place of the template's video: the app's rings, drawn
 * huge and slowly turning, in the three profile colours. */
function HeroArt() {
  return (
    <div className="hero__art" aria-hidden="true">
      <div className="hero__orbit hero__orbit--a" />
      <div className="hero__orbit hero__orbit--b" />
      <div className="hero__orbit hero__orbit--c" />
      <div className="hero__glow" />
    </div>
  )
}

export function Hero() {
  return (
    <section className="hero" aria-labelledby="hero-title">
      <HeroArt />
      <div className="container hero__container">
        <div className="hero__content">
          <div className="hero__title">
            <a className="badge" href="#how-it-works">
              <Sparkle className="badge__icon" size={12} strokeWidth={2.5} aria-hidden="true" />
              <span className="badge__text">
                <span>{hero.badge}</span>
                <span className="badge__shine" aria-hidden="true">
                  {hero.badge}
                </span>
              </span>
            </a>
            <h1 id="hero-title" className="t-h1 hero__h1">
              <Words text={hero.title} />
            </h1>
            <p className="t-lead hero__lead">{hero.lead}</p>
          </div>
          <div className="buttons hero__buttons">
            <Button link={hero.primary} />
            <Button link={hero.secondary} variant="glass" />
          </div>
        </div>
      </div>
    </section>
  )
}
