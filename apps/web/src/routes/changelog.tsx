import { createFileRoute } from '@tanstack/react-router'
import changelog from '../../../../CHANGELOG.md'
import { Prose, Toc } from '../components/Prose'
import { Shell } from '../components/Shell'
import { pageHead } from '../lib/head'
import { site } from '../site'

const description =
  'What changed in Claude Notch, its command line and this site, newest first. To update, pull and run install.sh again.'

// The file's own opening line is the lead here.
const html = changelog.html.replace(/^<p>[\s\S]*?<\/p>\n?/, '')
const releases = changelog.toc.filter((item) => item.depth === 2)

export const Route = createFileRoute('/changelog')({
  head: () => pageHead({ title: 'Changelog', description, path: '/changelog/' }),
  component: Changelog,
})

function Changelog() {
  return (
    <Shell className="changelog">
      <div className="container guide__grid">
        <article className="article">
          <header className="article__header">
            <p className="article__eyebrow">Changelog</p>
            <h1 className="article__title">What’s new</h1>
            <p className="article__lead">
              What changed in Claude Notch, its command line and this site, newest first. To update,
              run <code>cd ~/claude-multi-account &amp;&amp; git pull &amp;&amp; ./install.sh</code>
              .
            </p>
          </header>
          <Prose html={html} className="changelog__body" />
          <footer className="article__footer">
            <a
              className="article__edit"
              href={`${site.repo}/commits/main`}
              target="_blank"
              rel="noreferrer"
            >
              Every commit on GitHub
            </a>
          </footer>
        </article>
        <div className="docs__aside">
          <Toc items={releases} />
        </div>
      </div>
    </Shell>
  )
}
