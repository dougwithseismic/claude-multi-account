import { ArrowLeft, ArrowRight, Menu } from 'lucide-react'
import type { ReactNode } from 'react'
import { docGroups, neighbours, type Page } from '../lib/pages'
import { site, to } from '../site'
import { Prose, Toc } from './Prose'
import { Shell } from './Shell'

/** The docs sidebar: every page, grouped, the current one marked. */
function Sidebar({ current }: { current?: string }) {
  const groups = docGroups()
  const links = (
    <div className="docs-nav__groups">
      <a className="docs-nav__home" href={site.docs} aria-current={current ? undefined : 'page'}>
        Overview
      </a>
      {groups.map((group) => (
        <div key={group.section} className="docs-nav__group">
          <p className="docs-nav__title">{group.section}</p>
          <ul>
            {group.pages.map((page) => (
              <li key={page.slug}>
                <a
                  href={to(`/docs/${page.slug}/`)}
                  aria-current={current === page.slug ? 'page' : undefined}
                >
                  {page.title}
                </a>
              </li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  )
  const currentTitle = groups.flatMap((g) => g.pages).find((p) => p.slug === current)?.title
  return (
    <aside className="docs-nav" aria-label="Docs">
      <details className="docs-nav__menu">
        <summary>
          <Menu size={16} aria-hidden="true" />
          <span>{currentTitle ?? 'Overview'}</span>
          <span className="docs-nav__hint">All docs</span>
        </summary>
        {links}
      </details>
      <div className="docs-nav__full">{links}</div>
    </aside>
  )
}

export function DocsLayout({ page }: { page: Page }) {
  const { meta, html, toc } = page
  const { prev, next } = neighbours(meta.slug)
  return (
    <DocsFrame current={meta.slug} toc={<Toc items={toc} />}>
      <header className="article__header">
        <p className="article__eyebrow">{meta.section}</p>
        <h1 className="article__title">{meta.title}</h1>
        <p className="article__lead">{meta.description}</p>
      </header>
      <Prose html={html} />
      <footer className="article__footer">
        <nav className="pager" aria-label="Next and previous">
          {prev ? (
            <a className="pager__link" href={to(`/docs/${prev.slug}/`)}>
              <span className="pager__dir">
                <ArrowLeft size={14} aria-hidden="true" /> Previous
              </span>
              <span className="pager__title">{prev.title}</span>
            </a>
          ) : (
            <span />
          )}
          {next && (
            <a className="pager__link pager__link--next" href={to(`/docs/${next.slug}/`)}>
              <span className="pager__dir">
                Next <ArrowRight size={14} aria-hidden="true" />
              </span>
              <span className="pager__title">{next.title}</span>
            </a>
          )}
        </nav>
        <a
          className="article__edit"
          href={site.edit(`docs/${meta.slug}.md`)}
          target="_blank"
          rel="noreferrer"
        >
          Suggest a change to this page
        </a>
      </footer>
    </DocsFrame>
  )
}

/** Sidebar, article and "On this page", shared by every docs page and the overview. */
export function DocsFrame({
  current,
  toc,
  children,
}: {
  current?: string
  toc?: ReactNode
  children: ReactNode
}) {
  return (
    <Shell className="docs">
      <div className="container docs__grid">
        <Sidebar current={current} />
        <article className="article">{children}</article>
        <div className="docs__aside">{toc}</div>
      </div>
    </Shell>
  )
}
