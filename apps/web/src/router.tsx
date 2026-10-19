import { createRouter } from '@tanstack/react-router'
import { routeTree } from './routeTree.gen'

export function getRouter() {
  // Every page is a folder with an index.html, so links end in a slash and GitHub Pages
  // never redirects them.
  return createRouter({ routeTree, scrollRestoration: true, trailingSlash: 'always' })
}
