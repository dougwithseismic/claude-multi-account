import { createFileRoute } from '@tanstack/react-router'
import { SetupPlanner } from '../../components/tools/SetupPlanner'
import { ToolPage } from '../../components/tools/ToolPage'
import { pageHead } from '../../lib/head'
import { to } from '../../site'

const lead =
  'Plan your copies of Claude: how many, and each one’s name, colour and hotkey. Get the commands that set it up.'

export const Route = createFileRoute('/tools/setup')({
  head: () =>
    pageHead({ title: 'Claude Notch setup planner', description: lead, path: '/tools/setup/' }),
  component: SetupPage,
})

function SetupPage() {
  return (
    <ToolPage
      title="Setup planner"
      lead={lead}
      footer={
        <p>
          Change any of it later in profiles.json:{' '}
          <a href={to('/docs/profiles/')}>Names, colours and keys</a> explains each field.
        </p>
      }
    >
      <SetupPlanner />
    </ToolPage>
  )
}
