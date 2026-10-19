import { createFileRoute } from '@tanstack/react-router'
import { ArrowRight } from 'lucide-react'
import { Shell } from '../../components/Shell'
import { pageHead } from '../../lib/head'
import { list } from '../../lib/pages'
import { to } from '../../site'

const description =
  "How Claude's 5-hour and weekly limits work, what each plan gets, how to pace yourself, and how to run more than one account. Each guide lists its sources, most of them Anthropic's own pages."

export const Route = createFileRoute('/learn/')({
  head: () =>
    pageHead({ title: "Learn: Claude's usage limits, explained", description, path: '/learn/' }),
  component: LearnIndex,
})

function LearnIndex() {
  return (
    <Shell className="learn-index">
      <div className="container">
        <header className="page-head">
          <p className="page-head__eyebrow">Learn</p>
          <h1 className="page-head__title">Claude's usage limits, explained</h1>
          <p className="page-head__lead">{description}</p>
        </header>
        <div className="card-grid">
          {list('learn').map((guide) => (
            <a key={guide.slug} className="card-link" href={to(`/learn/${guide.slug}/`)}>
              <span className="card-link__kicker">{guide.minutes} min read</span>
              <span className="card-link__title">{guide.title}</span>
              <span className="card-link__body">{guide.summary ?? guide.description}</span>
              <span className="card-link__more">
                Read <ArrowRight size={14} aria-hidden="true" />
              </span>
            </a>
          ))}
        </div>
      </div>
    </Shell>
  )
}
