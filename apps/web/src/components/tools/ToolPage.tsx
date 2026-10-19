import { ArrowLeft } from 'lucide-react'
import type { ReactNode } from 'react'
import { site } from '../../site'
import { Shell } from '../Shell'

/** A tool's page: its heading, the tool, and a short note on where to go next. */
export function ToolPage({
  title,
  lead,
  children,
  footer,
}: {
  title: string
  lead: string
  children: ReactNode
  footer?: ReactNode
}) {
  return (
    <Shell className="tool-page">
      <div className="container">
        <header className="page-head tool-page__head">
          <a className="page-head__eyebrow guide__back" href={site.tools}>
            <ArrowLeft size={14} aria-hidden="true" /> Tools
          </a>
          <h1 className="page-head__title">{title}</h1>
          <p className="page-head__lead">{lead}</p>
        </header>
        {children}
        {footer && <div className="tool-page__footer">{footer}</div>}
      </div>
    </Shell>
  )
}
