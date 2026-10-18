import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import viteReact from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  // GitHub Pages serves the site under /claude-multi-account/; the Pages workflow sets
  // BASE_PATH. Start derives the router's basepath from this.
  base: process.env.BASE_PATH ?? '/',
  server: { port: 5173, strictPort: true },
  plugins: [
    // The page is static: every route is rendered to HTML at build time.
    tanstackStart({ prerender: { enabled: true, crawlLinks: true } }),
    viteReact(),
  ],
})
