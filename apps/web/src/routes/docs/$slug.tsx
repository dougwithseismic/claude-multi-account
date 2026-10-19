import { createFileRoute, notFound } from '@tanstack/react-router'
import { DocsLayout } from '../../components/DocsLayout'
import { pageHead } from '../../lib/head'
import { load } from '../../lib/pages'

export const Route = createFileRoute('/docs/$slug')({
  loader: async ({ params }) => {
    const page = await load('docs', params.slug)
    if (!page) throw notFound()
    return page
  },
  head: ({ loaderData, params }) =>
    loaderData
      ? pageHead({
          title: loaderData.meta.title,
          description: loaderData.meta.description,
          path: `/docs/${params.slug}/`,
          type: 'article',
        })
      : {},
  component: DocPage,
})

function DocPage() {
  return <DocsLayout page={Route.useLoaderData()} />
}
