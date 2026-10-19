import { createFileRoute } from '@tanstack/react-router'
import { PaceCalculator } from '../../components/tools/PaceCalculator'
import { ToolPage } from '../../components/tools/ToolPage'
import { pageHead } from '../../lib/head'
import { site, to } from '../../site'

const lead =
  "Will your 5-hour or weekly Claude limit last until it resets? Enter what you've used and when it resets. Nothing leaves your browser."

export const Route = createFileRoute('/tools/pace')({
  head: () =>
    pageHead({
      title: 'Claude limit pace calculator',
      description: lead,
      path: '/tools/pace/',
    }),
  component: PacePage,
})

function PacePage() {
  return (
    <ToolPage
      title="Pace calculator"
      lead={lead}
      footer={
        <>
          <p>
            The arithmetic is in{' '}
            <a href={to('/learn/pacing/')}>Pacing: will it last until the reset?</a> On a Mac,{' '}
            <a href={site.install}>Claude Notch</a> puts this tick on every limit, for every
            account, beside the notch.
          </p>
        </>
      }
    >
      <PaceCalculator />
    </ToolPage>
  )
}
