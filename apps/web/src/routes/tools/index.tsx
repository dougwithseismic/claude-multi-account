import { createFileRoute } from '@tanstack/react-router'
import { ArrowRight } from 'lucide-react'
import { Shell } from '../../components/Shell'
import { pageHead } from '../../lib/head'
import { to } from '../../site'

const description =
  'Free tools for anyone who uses Claude, in the browser, with nothing to install and nothing sent anywhere.'

const tools = [
  {
    path: '/tools/pace/',
    kicker: 'Any platform',
    title: 'Pace calculator',
    body: 'Enter how much of a 5-hour or weekly limit you’ve used and when it resets. See whether it lasts, and when you’d run out if it doesn’t.',
  },
  {
    path: '/tools/setup/',
    kicker: 'For Claude Notch',
    title: 'Setup planner',
    body: 'Pick how many accounts, their names, colours and hotkeys. Get the install command and the profiles.json to match.',
  },
]

export const Route = createFileRoute('/tools/')({
  head: () => pageHead({ title: 'Tools', description, path: '/tools/' }),
  component: ToolsIndex,
})

function ToolsIndex() {
  return (
    <Shell>
      <div className="container">
        <header className="page-head">
          <p className="page-head__eyebrow">Tools</p>
          <h1 className="page-head__title">Work out your limits</h1>
          <p className="page-head__lead">{description}</p>
        </header>
        <div className="card-grid">
          {tools.map((tool) => (
            <a key={tool.path} className="card-link" href={to(tool.path)}>
              <span className="card-link__kicker">{tool.kicker}</span>
              <span className="card-link__title">{tool.title}</span>
              <span className="card-link__body">{tool.body}</span>
              <span className="card-link__more">
                Open <ArrowRight size={14} aria-hidden="true" />
              </span>
            </a>
          ))}
        </div>
      </div>
    </Shell>
  )
}
