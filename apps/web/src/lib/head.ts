import { site, to } from '../site'

/** A page's own title, description, canonical URL and link preview. */
export function pageHead({
  title,
  description,
  path,
  image = 'og/default.png',
  type = 'website',
}: {
  title: string
  description: string
  /** The page's path on the site, like `/docs/install/`. */
  path: string
  image?: string
  type?: 'website' | 'article'
}) {
  const url = site.origin + to(path)
  const full = title === site.title ? title : `${title} · ${site.name}`
  return {
    meta: [
      { title: full },
      { name: 'description', content: description },
      { property: 'og:title', content: full },
      { property: 'og:description', content: description },
      { property: 'og:type', content: type },
      { property: 'og:url', content: url },
      { property: 'og:image', content: site.origin + to(image) },
      { property: 'og:site_name', content: site.name },
      { name: 'twitter:card', content: 'summary_large_image' },
      { name: 'twitter:title', content: full },
      { name: 'twitter:description', content: description },
      { name: 'twitter:image', content: site.origin + to(image) },
    ],
    links: [{ rel: 'canonical', href: url }],
  }
}
