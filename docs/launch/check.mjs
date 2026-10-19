// Checks each draft in docs/launch against its channel's length limits:
// node docs/launch/check.mjs
import { readFileSync } from 'node:fs'

const read = (file) => readFileSync(new URL(file, import.meta.url), 'utf8')

/** The text under `## heading`, up to the next heading. */
const section = (text, heading) =>
  text.split(`\n## ${heading}\n`)[1]?.split(/\n## /)[0]?.trim() ?? ''

// X counts every link as 23 characters.
const xLength = (post) => [...post.replace(/https?:\/\/\S+/g, 'x'.repeat(23))].length

const checks = [
  ['Show HN title', section(read('show-hn.md'), 'Title'), 80],
  ['Reddit title', section(read('reddit-claudeai.md'), 'Title'), 300],
  ['Product Hunt name', section(read('product-hunt.md'), 'Name'), 40],
  ['Product Hunt tagline', section(read('product-hunt.md'), 'Tagline'), 60],
  ['Product Hunt description', section(read('product-hunt.md'), 'Description'), 260],
  ...read('x-thread.md')
    .split('\n---\n')
    .slice(1)
    .map((post, i) => [`X post ${i + 1}`, post.trim(), 280]),
]

let failed = false
for (const [name, text, limit] of checks) {
  const length = name.startsWith('X') ? xLength(text) : [...text].length
  const ok = text.length > 0 && length <= limit
  if (!ok) failed = true
  console.log(`${ok ? '✓' : '✗'} ${name}: ${length} of ${limit}`)
}
process.exit(failed ? 1 : 0)
