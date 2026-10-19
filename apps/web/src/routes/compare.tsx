import { createFileRoute } from '@tanstack/react-router'
import compare from '../../content/compare.md'
import { longDate } from '../components/Guide'
import { Prose, Toc } from '../components/Prose'
import { Shell } from '../components/Shell'
import { pageHead } from '../lib/head'

const { meta, html, toc } = compare

export const Route = createFileRoute('/compare')({
  head: () => pageHead({ title: meta.title, description: meta.description, path: '/compare/' }),
  component: Compare,
})

function Compare() {
  return (
    <Shell className="compare">
      <div className="container guide__grid">
        <article className="article">
          <header className="article__header">
            <p className="article__eyebrow">Compare</p>
            <h1 className="article__title">{meta.title}</h1>
            <p className="article__lead">{meta.description}</p>
            {meta.checked && <p className="guide__meta">Checked {longDate(meta.checked)}</p>}
          </header>
          <Prose html={html} />
        </article>
        <div className="docs__aside">
          <Toc items={toc.filter((item) => item.depth === 2)} />
        </div>
      </div>
    </Shell>
  )
}
