import { readFileSync } from 'node:fs'
import type { Plugin } from 'vite'

/**
 * Files from elsewhere in the repo, served at the site's root under another name:
 * `{ 'install.sh': new URL('../../bootstrap.sh', import.meta.url) }`. The dev server
 * reads them on each request; the build copies them in, so there's no second copy to
 * keep in step.
 */
export function rootFiles(files: Record<string, URL>): Plugin {
  return {
    name: 'notch-root-files',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const path = req.url?.split('?')[0]
        const name = Object.keys(files).find((file) => path === `${server.config.base}${file}`)
        const url = name && files[name]
        if (!url) return next()
        res.setHeader('Content-Type', 'text/plain; charset=utf-8')
        res.end(readFileSync(url))
      })
    },
    generateBundle() {
      if (this.environment.name !== 'client') return
      for (const [fileName, url] of Object.entries(files)) {
        this.emitFile({ type: 'asset', fileName, source: readFileSync(url) })
      }
    },
  }
}
