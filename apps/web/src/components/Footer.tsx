import { footer } from '../content'
import { Logo } from './Logo'
import { external } from './ui'

export function Footer() {
  return (
    <footer className="footer">
      <div className="container footer__container">
        <div className="footer__brand">
          <Logo />
          <p className="t-body">{footer.tagline}</p>
        </div>
        <nav className="footer__columns" aria-label="Footer">
          {footer.columns.map((column) => (
            <div key={column.title} className="footer__column">
              <h2 className="footer__title">{column.title}</h2>
              <ul className="footer__links">
                {column.links.map((link) => (
                  <li key={link.label}>
                    <a className="footer__link" href={link.href} {...external(link)}>
                      {link.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </nav>
        <div className="footer__legal">
          <span>{footer.copyright}</span>
          <span>{footer.legal}</span>
        </div>
      </div>
    </footer>
  )
}
