import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { Marked, type Tokens } from 'marked'
import type { Plugin } from 'vite'
import { parse as parseYaml } from 'yaml'

/** One `##` or `###` heading, for "On this page". */
export type TocItem = { id: string; text: string; depth: 2 | 3 }

/**
 * Compiles `content/**\/*.md` at build time, so no Markdown parser ships to the browser.
 *
 * - `import page from './x.md'` gives `{ meta, html, toc }`: the frontmatter, the body as
 *   HTML, and its headings.
 * - `import { meta } from './x.md?meta'` gives the frontmatter alone, for indexes, so a
 *   sidebar doesn't pull every page's HTML into its chunk.
 *
 * Links starting with `/` get the site's base path, external links open in a new tab,
 * headings get ids, `> **Note**` blockquotes become callouts, and code blocks get a copy
 * button that the page wires up.
 */
export function markdown(): Plugin {
  let base = '/'
  return {
    name: 'notch-markdown',
    enforce: 'pre',
    configResolved(config) {
      base = config.base
    },
    transform(code, id) {
      const [path, query] = id.split('?')
      if (!path?.endsWith('.md')) return
      const { meta: front, body } = frontmatter(code, path)
      const words = body.split(/\s+/).filter(Boolean).length
      const meta = { ...front, minutes: Math.max(1, Math.round(words / 220)) }
      if (query === 'meta')
        return { code: `export const meta = ${JSON.stringify(meta)}`, map: null }
      const { html, toc } = render(body, base)
      return {
        code: [
          `export const meta = ${JSON.stringify(meta)}`,
          `export const html = ${JSON.stringify(html)}`,
          `export const toc = ${JSON.stringify(toc)}`,
          'export default { meta, html, toc }',
        ].join('\n'),
        map: null,
      }
    },
  }
}

/** Every page's path under the site, for the prerenderer and the sitemap. */
export function contentRoutes(root: string) {
  const routes: string[] = []
  for (const section of ['docs', 'learn']) {
    const dir = join(root, section)
    for (const file of readdirSync(dir).filter((f) => f.endsWith('.md'))) {
      const { meta } = frontmatter(readFileSync(join(dir, file), 'utf8'), file)
      if (meta.draft) continue
      routes.push(`/${section}/${file.replace(/\.md$/, '')}`)
    }
  }
  return routes
}

/** The YAML between `---` lines, or for a file without any (CHANGELOG.md), its `# Title`. */
function frontmatter(source: string, path: string) {
  const match = source.match(/^---\n([\s\S]*?)\n---\n?/)
  const heading = match ? null : source.match(/^# (.+)\n/)
  const meta = (match ? parseYaml(match[1] ?? '') : { title: heading?.[1] }) as Record<
    string,
    unknown
  >
  if (typeof meta.title !== 'string') throw new Error(`${path}: frontmatter needs a title`)
  const slug = path.split('/').pop()?.replace(/\.md$/, '') ?? ''
  const cut = match?.[0] ?? heading?.[0] ?? ''
  return {
    meta: { ...meta, slug } as Record<string, unknown> & { slug: string; draft?: boolean },
    body: source.slice(cut.length),
  }
}

export function slugify(text: string) {
  return text
    .toLowerCase()
    .replace(/<[^>]+>/g, '')
    .replace(/&[a-z]+;|&#\d+;/g, '')
    .replace(/[`*_~'’"“”()[\]{}:;,.!?/\\|@#$%^&+=<>·—–]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
}

const decode = (s: string) =>
  s
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')

const escape = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')

const callouts = { note: 'Note', tip: 'Tip', warning: 'Warning' } as const

function render(body: string, base: string) {
  const toc: TocItem[] = []
  const seen = new Map<string, number>()
  // Pages are folders (`/docs/install/index.html`), so internal links end in a slash and
  // GitHub Pages never has to redirect them.
  const withBase = (href: string) => {
    if (!href.startsWith('/') || href.startsWith('//')) return href
    const cut = href.search(/[#?]/)
    const path = cut < 0 ? href : href.slice(0, cut)
    const rest = cut < 0 ? '' : href.slice(cut)
    const slashed = path.endsWith('/') || /\.[a-z0-9]+$/i.test(path) ? path : `${path}/`
    return base.replace(/\/$/, '') + slashed + rest
  }

  const marked = new Marked({ gfm: true })
  marked.use({
    renderer: {
      heading({ tokens, depth }: Tokens.Heading) {
        const inner = this.parser.parseInline(tokens)
        const plain = decode(inner.replace(/<[^>]+>/g, ''))
        // A release heading ("0.5 — 2026-10-19") is anchored by its version: #0-5.
        const version = plain.match(/^(\d+(?:\.\d+)+)\b/)?.[1]
        let id = version ? version.replace(/\./g, '-') : slugify(plain)
        const n = seen.get(id) ?? 0
        seen.set(id, n + 1)
        if (n) id = `${id}-${n}`
        if (depth === 2 || depth === 3) toc.push({ id, text: plain, depth })
        if (depth === 1) return `<h1>${inner}</h1>\n`
        return `<h${depth} id="${id}"><a class="anchor" href="#${id}" aria-hidden="true" tabindex="-1">#</a>${inner}</h${depth}>\n`
      },
      code({ text, lang }: Tokens.Code) {
        const language = (lang ?? '').split(/\s/)[0] ?? ''
        const shell = ['bash', 'sh', 'zsh', 'shell', 'console'].includes(language)
        return [
          `<div class="code"${language ? ` data-lang="${escape(language)}"` : ''}>`,
          `<pre><code>${escape(text)}</code></pre>`,
          shell || language === 'json'
            ? '<button type="button" class="code__copy" data-copy>Copy</button>'
            : '',
          '</div>\n',
        ].join('')
      },
      blockquote({ tokens }: Tokens.Blockquote) {
        const inner = this.parser.parse(tokens)
        const match = inner.match(/^<p><strong>(Note|Tip|Warning):?<\/strong>:?\s*/)
        if (!match) return `<blockquote>${inner}</blockquote>\n`
        const kind = (match[1] ?? 'Note').toLowerCase() as keyof typeof callouts
        return `<aside class="callout callout--${kind}"><p><strong class="callout__label">${callouts[kind]}</strong>${inner.slice(match[0].length)}</aside>\n`
      },
      link({ href, title, tokens }: Tokens.Link) {
        const inner = this.parser.parseInline(tokens)
        const external = /^https?:\/\//.test(href)
        const attrs = [
          `href="${escape(withBase(href))}"`,
          title ? `title="${escape(title)}"` : '',
          external ? 'target="_blank" rel="noreferrer"' : '',
        ]
          .filter(Boolean)
          .join(' ')
        return `<a ${attrs}>${inner}</a>`
      },
      table(token: Tokens.Table) {
        const cell = (c: Tokens.TableCell) => {
          const tag = c.header ? 'th' : 'td'
          const align = c.align ? ` style="text-align:${c.align}"` : ''
          return `<${tag}${align}>${this.parser.parseInline(c.tokens)}</${tag}>`
        }
        const head = `<tr>${token.header.map(cell).join('')}</tr>`
        const rows = token.rows.map((row) => `<tr>${row.map(cell).join('')}</tr>`).join('')
        return `<div class="table"><table><thead>${head}</thead><tbody>${rows}</tbody></table></div>\n`
      },
    },
  })
  const html = marked.parse(body, { async: false })
  return { html, toc }
}
