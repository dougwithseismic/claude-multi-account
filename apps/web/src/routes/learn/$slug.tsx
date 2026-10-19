import { createFileRoute, notFound } from '@tanstack/react-router'
import { GuideLayout } from '../../components/Guide'
import { pageHead } from '../../lib/head'
import { load } from '../../lib/pages'

export const Route = createFileRoute('/learn/$slug')({
  loader: async ({ params }) => {
    const page = await load('learn', params.slug)
    if (!page) throw notFound()
    return page
  },
  head: ({ loaderData, params }) =>
    loaderData
      ? pageHead({
          title: loaderData.meta.title,
          description: loaderData.meta.description,
          path: `/learn/${params.slug}/`,
          type: 'article',
        })
      : {},
  component: GuidePage,
})

function GuidePage() {
  return <GuideLayout page={Route.useLoaderData()} />
}
