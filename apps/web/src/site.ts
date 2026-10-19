/** Where the page's outbound links go. */
const repo = 'https://github.com/dougwithseismic/claude-multi-account'

/** A path on this site, with the base path GitHub Pages serves it under. */
export const to = (path: string) => `${import.meta.env.BASE_URL}${path.replace(/^\//, '')}`

export const site = {
  name: 'Claude Notch',
  title: 'Claude Notch: every Claude account open at once',
  description:
    'Run the Claude desktop app once per account, each signed in on its own, and see every 5-hour and weekly limit beside the MacBook notch. Free, for macOS 26.',
  origin: 'https://dougwithseismic.github.io',
  repo,
  install: to('/docs/install/'),
  signIn: to('/docs/sign-in/'),
  addCopy: to('/docs/profiles/#add-more-copies'),
  undo: to('/docs/updating/#uninstall'),
  cli: to('/docs/claude-usage/'),
  docs: to('/docs/'),
  learn: to('/learn/'),
  tools: to('/tools/'),
  changelog: to('/changelog/'),
  compare: to('/compare/'),
  prd: `${repo}/blob/main/docs/notch-prd.md`,
  /** The one-line install, which runs bootstrap.sh. */
  installLine: 'curl -fsSL https://dougwithseismic.github.io/claude-multi-account/install.sh | zsh',
  /** The GitHub page that edits a docs page or guide. */
  edit: (path: string) => `${repo}/edit/main/apps/web/content/${path}`,
} as const
