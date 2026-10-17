import { useRef } from 'react'
import { facts } from '../content'
import { Scene } from './notch/Scenes'
import { Button } from './ui'
import { useCountUp } from './useCountUp'
import { useInViewOnce } from './useScrollProgress'

type Item = (typeof facts.items)[number]

function Stat({ stat }: { stat: Item['stats'][number] }) {
  const ref = useRef<HTMLDivElement>(null)
  const shown = useCountUp(ref, stat.value)
  return (
    <div className="fact__stat" ref={ref}>
      {/* The final figure holds the width while the count runs over it. */}
      <p className="fact__value">
        <span aria-hidden="true" className="fact__value-room">
          {stat.value}
          {stat.suffix}
        </span>
        <span className="fact__value-count">
          {shown}
          {stat.suffix}
        </span>
      </p>
      <p className="fact__label">{stat.label}</p>
    </div>
  )
}

function Fact({ item }: { item: Item }) {
  const media = useRef<HTMLDivElement>(null)
  const seen = useInViewOnce(media)
  return (
    <div className="fact">
      <div className="fact__text">
        <div className="fact__head">
          <p className="t-quote">{item.quote}</p>
          <div className="fact__stats">
            {item.stats.map((stat) => (
              <Stat key={stat.label} stat={stat} />
            ))}
          </div>
        </div>
        <Button link={item.cta} variant="glass" />
      </div>
      <div className="fact__media" ref={media}>
        <Scene name={item.scene} tint={item.tint} shown={seen} />
      </div>
    </div>
  )
}

export function Facts() {
  return (
    <section className="facts" aria-labelledby="facts-title">
      <div className="container facts__container">
        <h2 id="facts-title" className="t-h2 facts__title">
          {facts.title}
        </h2>
        <div className="facts__list">
          {facts.items.map((item) => (
            <Fact key={item.scene} item={item} />
          ))}
        </div>
      </div>
    </section>
  )
}
