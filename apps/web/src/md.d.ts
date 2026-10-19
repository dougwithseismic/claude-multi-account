/** Markdown in `content/`, compiled by `plugins/markdown.ts`. */
declare module '*.md' {
  const page: import('./lib/pages').Page
  export default page
  export const meta: import('./lib/pages').PageMeta
  export const html: string
  export const toc: import('./lib/pages').TocItem[]
}

declare module '*.md?meta' {
  export const meta: import('./lib/pages').PageMeta
}
