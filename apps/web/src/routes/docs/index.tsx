import { createFileRoute } from '@tanstack/react-router'
import { ArrowRight } from 'lucide-react'
import { DocsFrame } from '../../components/DocsLayout'
import { pageHead } from '../../lib/head'
import { docGroups } from '../../lib/pages'
import { site, to } from '../../site'

const description =
  'Install Claude Notch, sign in to each copy of Claude, read the panel, and fix anything that goes wrong.'

export const Route = createFileRoute('/docs/')({
  head: () => pageHead({ title: 'Docs', description, path: '/docs/' }),
  component: DocsHome,
})

function DocsHome() {
  return (
    <DocsFrame>
      <header className="article__header">
        <p className="article__eyebrow">Docs</p>
        <h1 className="article__title">Everything Claude Notch does, and how to set it up</h1>
        <p className="article__lead">{description}</p>
      </header>
      <a className="docs-start" href={site.install}>
        <span>
          <span className="docs-start__label">New here?</span>
          <span className="docs-start__title">Install it in one command</span>
        </span>
        <ArrowRight size={18} aria-hidden="true" />
      </a>
      {docGroups().map((group) => (
        <section key={group.section} className="docs-index">
          <h2 className="docs-index__title">{group.section}</h2>
          <ul className="docs-index__list">
            {group.pages.map((page) => (
              <li key={page.slug}>
                <a className="docs-index__item" href={to(`/docs/${page.slug}/`)}>
                  <span className="docs-index__name">{page.title}</span>
                  <span className="docs-index__desc">{page.description}</span>
                </a>
              </li>
            ))}
          </ul>
        </section>
      ))}
    </DocsFrame>
  )
}
