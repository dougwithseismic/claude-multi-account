import { ArrowLeft, ArrowRight } from 'lucide-react'
import type { ReactNode } from 'react'
import { list, type Page } from '../lib/pages'
import { site, to } from '../site'
import { UsageFigure } from './figures/UsageFigure'
import { Prose, Toc } from './Prose'
import { Shell } from './Shell'

/** Figures a guide can place with `<div data-figure="name"></div>` on a line of its own. */
const figures: Record<string, () => ReactNode> = {
  rings: () => <UsageFigure variant="rings" />,
  pace: () => <UsageFigure variant="pace" />,
}

const placeholder = /<div data-figure="([a-z-]+)"><\/div>\n?/

/** A guide's HTML, with its figures in place. */
function Body({ html }: { html: string }) {
  const parts = html.split(placeholder)
  return (
    <>
      {parts.map((part, i) =>
        i % 2 === 0 ? (
          part.trim() && <Prose key={`html-${i}`} html={part} />
        ) : (
          <div key={`figure-${part}`}>{figures[part]?.()}</div>
        ),
      )}
    </>
  )
}

/** "19 October 2026", the same on the server and in every browser. */
export function longDate(iso: string) {
  return new Date(`${iso}T00:00:00Z`).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  })
}

export function GuideLayout({ page }: { page: Page }) {
  const { meta, html, toc } = page
  const guides = list('learn')
  const i = guides.findIndex((guide) => guide.slug === meta.slug)
  const next = guides[(i + 1) % guides.length]
  const sources = meta.sources ?? []
  const items = sources.length
    ? [...toc, { id: 'sources', text: 'Sources', depth: 2 as const }]
    : toc

  return (
    <Shell className="guide">
      <div className="container guide__grid">
        <article className="article guide__article">
          <header className="article__header">
            <a className="article__eyebrow guide__back" href={site.learn}>
              <ArrowLeft size={14} aria-hidden="true" /> Learn
            </a>
            <h1 className="article__title">{meta.title}</h1>
            <p className="article__lead">{meta.description}</p>
            <p className="guide__meta">
              {meta.minutes} min read
              {meta.checked && <> · Sources checked {longDate(meta.checked)}</>}
            </p>
          </header>
          <Body html={html} />
          {sources.length > 0 && (
            <section className="sources" aria-labelledby="sources">
              <h2 id="sources" className="sources__title">
                Sources
              </h2>
              <ol className="sources__list">
                {sources.map((source) => (
                  <li key={source.url}>
                    <a href={source.url} target="_blank" rel="noreferrer">
                      {source.title}
                    </a>
                  </li>
                ))}
              </ol>
              <p className="sources__note">
                {meta.checked && <>Checked against these pages on {longDate(meta.checked)}. </>}
                Claude Notch isn't made by Anthropic; where this guide and Anthropic's pages
                disagree, Anthropic's are right.{' '}
                <a href={site.edit(`learn/${meta.slug}.md`)} target="_blank" rel="noreferrer">
                  Suggest a change
                </a>
              </p>
            </section>
          )}
          {next && next.slug !== meta.slug && (
            <a
              className="pager__link pager__link--next guide__next"
              href={to(`/learn/${next.slug}/`)}
            >
              <span className="pager__dir">
                Next guide <ArrowRight size={14} aria-hidden="true" />
              </span>
              <span className="pager__title">{next.title}</span>
            </a>
          )}
        </article>
        <div className="docs__aside">
          <Toc items={items} />
        </div>
      </div>
    </Shell>
  )
}
