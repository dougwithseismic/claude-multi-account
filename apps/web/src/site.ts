/** Where the page's outbound links go. The repository is private for now, so these
 * only work for people with access until it (or a release) is public. */
const repo = 'https://github.com/dougwithseismic/claude-multi-account'

export const site = {
  title: 'Claude Notch: every Claude account open at once',
  description:
    'Run the Claude desktop app once per account, each signed in on its own, and see every 5-hour and weekly limit beside the MacBook notch. Free, for macOS 26.',
  repo,
  install: `${repo}#install`,
  signIn: `${repo}#sign-in-to-b-and-c`,
  addCopy: `${repo}#add-more-copies`,
  undo: `${repo}#uninstall`,
  cli: `${repo}#claude-usage`,
  prd: `${repo}/blob/main/docs/notch-prd.md`,
} as const
