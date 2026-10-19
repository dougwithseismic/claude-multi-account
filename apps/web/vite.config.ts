import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import viteReact from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import { contentRoutes, markdown } from './plugins/markdown'
import { rootFiles } from './plugins/root-files'

// GitHub Pages serves the site under /claude-multi-account/; the Pages workflow sets
// BASE_PATH. Start derives the router's basepath from this.
const base = process.env.BASE_PATH ?? '/'

/** Where the site lives, for the sitemap. */
const host = 'https://dougwithseismic.github.io'

/**
 * Every page, written the way links on the site are (base path, trailing slash), so the
 * crawler doesn't count a page twice and the sitemap lists each once.
 */
const pages = [
  '/',
  '/changelog/',
  '/docs/',
  '/learn/',
  '/tools/',
  '/tools/pace/',
  '/tools/setup/',
  ...contentRoutes(new URL('./content', import.meta.url).pathname).map((path) => `${path}/`),
].map((path) => ({ path: base.replace(/\/$/, '') + path }))

export default defineConfig({
  base,
  server: { port: 5173, strictPort: true },
  plugins: [
    markdown(),
    // The one-line install: curl -fsSL …/install.sh | zsh
    rootFiles({ 'install.sh': new URL('../../bootstrap.sh', import.meta.url) }),
    // The site is static: every route is rendered to HTML at build time. Crawling checks
    // the links between pages too, and fails the build on one that's broken.
    tanstackStart({
      prerender: {
        enabled: true,
        crawlLinks: true,
        failOnError: true,
        autoStaticPathsDiscovery: false,
        // A link to a section ("/#features") is the same page.
        onSuccess: ({ page }) =>
          page.path.includes('#') ? { ...page, sitemap: { exclude: true } } : undefined,
      },
      pages,
      sitemap: { enabled: true, host },
    }),
    viteReact(),
  ],
})
