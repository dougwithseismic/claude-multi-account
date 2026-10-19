import type { TocItem } from '../../plugins/markdown'

export type { TocItem }
export type Source = { title: string; url: string }

/** A docs page's or guide's frontmatter, plus what the Markdown plugin adds. */
export type PageMeta = {
  slug: string
  title: string
  description: string
  /** Docs: the sidebar group. */
  section?: string
  order?: number
  /** Guides: when the sources were last read, as YYYY-MM-DD. */
  checked?: string
  sources?: Source[]
  /** Guides: a short line for the index card. */
  summary?: string
  /** Reading time in minutes, from the word count. */
  minutes?: number
  draft?: boolean
}

export type Page = { meta: PageMeta; html: string; toc: TocItem[] }

type Kind = 'docs' | 'learn'

// Metadata eagerly, for the sidebar and indexes; each page's HTML only when it's opened.
const metas: Record<Kind, Record<string, PageMeta>> = {
  docs: import.meta.glob<PageMeta>('../../content/docs/*.md', {
    eager: true,
    query: '?meta',
    import: 'meta',
  }),
  learn: import.meta.glob<PageMeta>('../../content/learn/*.md', {
    eager: true,
    query: '?meta',
    import: 'meta',
  }),
}

const bodies: Record<Kind, Record<string, () => Promise<Page>>> = {
  docs: import.meta.glob<Page>('../../content/docs/*.md', { import: 'default' }),
  learn: import.meta.glob<Page>('../../content/learn/*.md', { import: 'default' }),
}

/** Every page of a kind, in order, drafts left out. */
export function list(kind: Kind): PageMeta[] {
  return Object.values(metas[kind])
    .filter((meta) => !meta.draft)
    .sort((a, b) => (a.order ?? 99) - (b.order ?? 99) || a.title.localeCompare(b.title))
}

export async function load(kind: Kind, slug: string): Promise<Page | null> {
  const entry = Object.entries(bodies[kind]).find(([path]) => path.endsWith(`/${slug}.md`))
  if (!entry) return null
  const page = await entry[1]()
  return page.meta.draft ? null : page
}

/** The docs sidebar's groups, in order. */
export const docSections = ['Start', 'Using it', 'Help'] as const

export function docGroups() {
  const pages = list('docs')
  return docSections.map((section) => ({
    section,
    pages: pages.filter((page) => page.section === section),
  }))
}

/** The pages either side of this one, in sidebar order. */
export function neighbours(slug: string) {
  const pages = docGroups().flatMap((group) => group.pages)
  const i = pages.findIndex((page) => page.slug === slug)
  return { prev: i > 0 ? pages[i - 1] : undefined, next: pages[i + 1] }
}
