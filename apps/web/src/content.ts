import { site } from './site'

/** Every word on the page. Facts come from the README and the PRD in this repo. */

export type Link = { label: string; href: string; external?: boolean }

export const nav = {
  links: [
    { label: 'Features', href: '#features' },
    { label: 'How it works', href: '#how-it-works' },
    { label: 'FAQ', href: '#faq' },
    { label: 'GitHub', href: site.repo, external: true },
  ] satisfies Link[],
  cta: { label: 'Install', href: site.install, external: true } satisfies Link,
}

export const hero = {
  badge: 'Free for macOS 26',
  // The word wrapped in * is set in the serif italic.
  title: 'Sign in once. Run every Claude account *side by side.*',
  lead: 'Each account gets its own copy of Claude, signed in for good. Switch with a key, and see every limit beside the notch.',
  primary: { label: 'Install', href: site.install, external: true } satisfies Link,
  secondary: { label: 'How it works', href: '#how-it-works' } satisfies Link,
}

export const platforms = {
  label: 'Made for the Claude desktop app on a Mac',
  items: [
    { icon: 'app', label: 'Claude desktop' },
    { icon: 'gauge', label: 'Pro and Max' },
    { icon: 'team', label: 'Team and Enterprise' },
    { icon: 'laptop', label: 'macOS 26' },
    { icon: 'notch', label: 'MacBook notch' },
    { icon: 'display', label: 'Any display' },
  ],
} as const

/** Why the project exists, in its author's words. `icon` marks an inline glyph. */
export const manifesto: Array<Array<string | { icon: 'rings' | 'window' | 'notch' }>> = [
  [
    'Switching Claude accounts used to mean signing out',
    { icon: 'window' },
    'and back in as someone else, every time a limit ran out.',
  ],
  [
    'Now each account runs in its own copy of Claude',
    { icon: 'rings' },
    'all open at once, signed in for good, a key press away.',
  ],
  [
    'And every account’s limits',
    { icon: 'notch' },
    'sit beside the notch, so I can see which one has room left and switch to it in a click.',
  ],
]

export const cards = {
  title: 'Every account, signed in at once',
  items: [
    {
      art: 'rings',
      title: 'A copy of Claude per account',
      body: 'Each copy keeps its own login and settings in its own data folder, so A, B and C stay signed in at the same time.',
      href: '#rings',
    },
    {
      art: 'keys',
      title: 'One key per account',
      body: '⌥⌘1, ⌥⌘2 and ⌥⌘3 bring that copy of Claude to the front, starting it if it’s closed, and outline its window in its colour.',
      href: '#peeks',
    },
    {
      art: 'links',
      title: 'Links land in the right copy',
      body: 'Sign-in and other claude:// links open in the copy of Claude you used last, rather than always in the first one.',
      href: '#panel',
    },
  ],
} as const

export const walkthrough = [
  {
    id: 'rings',
    tint: 'orange',
    tag: 'Collapsed',
    title: 'A ring for every account, beside the notch',
    body: 'The outer ring is the 5-hour window and the inner one the fullest weekly window, in that account’s colour. A red cross means it’s out for the week, and a dot marks the copy in front.',
    cta: { label: 'Install', href: site.install, external: true },
    scene: 'rings',
  },
  {
    id: 'panel',
    tint: 'blue',
    tag: 'Open',
    title: 'Rest on the notch to see everything',
    body: 'The panel grows out of the notch with a row per account: its plan, every window’s bar and when it resets. The white tick marks an even pace. Click a row to switch to that copy.',
    cta: { label: 'Install', href: site.install, external: true },
    scene: 'panel',
  },
  {
    id: 'peeks',
    tint: 'green',
    tag: 'Peeks',
    title: 'A word under the notch when it matters',
    body: 'Switch with ⌥⌘ and a number, and a strip under the notch names the copy you’re in. Pass 90% of a 5-hour limit, run out, or get one back, and it tells you for a few seconds.',
    cta: { label: 'Install', href: site.install, external: true },
    scene: 'peek',
  },
] as const

export const grid = {
  title: 'Everything else it does, and everything it leaves alone',
  items: [
    {
      icon: 'eye',
      title: 'Private by default',
      body: 'Rows show the profile’s name and plan, not the email or Team name, so the panel can open in front of anyone.',
    },
    {
      icon: 'team',
      title: 'Teams and organizations',
      body: 'One login can hold a personal plan and a Team, each with its own limits. The row shows the one in use.',
    },
    {
      icon: 'bell',
      title: 'Limit alerts',
      body: 'When the copy in use passes 90% of its 5-hour limit, runs out, or gets one back, a peek under the notch says so.',
    },
    {
      icon: 'frame',
      title: 'Window outline',
      body: 'An outline round the Claude window in front, drawn in that account’s colour, tells you which one you’re typing into.',
    },
    {
      icon: 'terminal',
      title: 'claude-usage',
      body: 'The same numbers in the terminal, with --json for scripts and --only to choose accounts.',
    },
    {
      icon: 'shield',
      title: 'Read only',
      body: 'It only reads: it never refreshes a login or writes to Claude’s files, so no copy is ever signed out because of it.',
    },
  ],
} as const

export const facts = {
  title: 'It stays quiet on the network and never touches Claude itself',
  items: [
    {
      quote:
        '“It checks each account every five minutes, and backs off whenever it’s rate-limited.”',
      stats: [
        { value: 5, suffix: ' min', label: 'Between reads' },
        { value: 6, suffix: ' h', label: 'Longest back-off' },
      ],
      cta: { label: 'Read the PRD', href: site.prd, external: true },
      scene: 'terminal',
      tint: 'blue',
    },
    {
      quote:
        '“Claude.app itself is never modified, so it stays signed and keeps updating as normal.”',
      stats: [
        { value: 3, suffix: '', label: 'Copies set up' },
        { value: 0, suffix: '', label: 'Changes to Claude' },
      ],
      cta: { label: 'Read the guide', href: site.repo, external: true },
      scene: 'profiles',
      tint: 'green',
    },
  ],
} as const

export const copies = {
  title: 'One ring for every copy of Claude you run',
  body: 'A, B and C come set up. Add D, E and more to profiles.json with a letter, label, colour and hotkey, then click Reload.',
  cta: { label: 'Add a copy', href: site.addCopy, external: true } satisfies Link,
}

export const details = {
  title: 'Small things, done well',
  items: [
    {
      art: 'hold',
      title: 'Hold ⌥ to see who',
      body: 'Emails and Team names stay hidden until you hold Option over the panel.',
    },
    {
      art: 'tick',
      title: 'The pace tick',
      body: 'A tick on each bar marks how far through its window you are.',
    },
    {
      art: 'cross',
      title: 'Out for the week',
      body: 'A red cross on the ring means that account has no weekly limit left.',
    },
    {
      art: 'countdown',
      title: 'Back in 4:12',
      body: 'With every copy out, the countdown shows the first one back.',
    },
    {
      art: 'pill',
      title: 'No notch, no problem',
      body: 'On a display without a notch, the rings sit in a small black pill.',
    },
    {
      art: 'haptic',
      title: 'Haptic feedback',
      body: 'A tick on the trackpad as the panel opens. Turn it off in settings.',
    },
    {
      art: 'login',
      title: 'Open at login',
      body: 'It starts with your Mac and has no Dock icon. Quit it from its panel.',
    },
    {
      art: 'update',
      title: 'Updates as normal',
      body: 'One update to Claude, and every copy runs it once reopened.',
    },
  ],
} as const

/** The PRD's three goals, quoted. */
export const goals = [
  {
    quote:
      '“See, without opening anything, which accounts have room left right now and when each one resets.”',
    role: 'Goal 1 of 3, Claude Notch PRD',
  },
  {
    quote: '“Pick the best account to work in and get to it in one click.”',
    role: 'Goal 2 of 3, Claude Notch PRD',
  },
  {
    quote: '“Never interfere with the Claude apps: read only, never sign anything out.”',
    role: 'Goal 3 of 3, Claude Notch PRD',
  },
].map((goal) => ({ ...goal, name: 'Doug Silkstone', initials: 'DS' }))

export const faq = {
  title: 'Before you install',
  items: [
    {
      q: 'Do I still have to sign out to switch accounts?',
      a: 'No. Each copy keeps its own login in its own data folder, so you sign in to B and C once and they stay signed in. To switch, press ⌥⌘ and its number, or click its row in the panel.',
    },
    {
      q: 'Does it change Claude.app?',
      a: 'No. Claude.app is never modified, so it stays signed and keeps updating as normal. Each extra copy is the same app started with its own data folder.',
    },
    {
      q: 'Why does it ask for Keychain access?',
      a: 'Each Claude copy encrypts its login with the “Claude Safe Storage” key, and the app reads the login to check usage. It never refreshes a login or writes to Claude’s files.',
    },
    {
      q: 'What does it send over the network?',
      a: 'Only the usage and profile checks Claude Code’s /usage makes: at launch, then every 5 minutes per account, backing off when Anthropic rate-limits the check.',
    },
    {
      q: 'How many accounts can I run at once?',
      a: 'A, B and C come set up, and you can add D, E and more in profiles.json. Each copy is a full Claude app, so expect roughly 0.5 to 1 GB of memory for each one you have open.',
    },
  ],
}

export const cta = {
  title: 'Ready to see every *limit?*',
  primary: { label: 'Install', href: site.install, external: true } satisfies Link,
  secondary: { label: 'Read the guide', href: site.repo, external: true } satisfies Link,
}

export const footer = {
  tagline: 'Every Claude account’s limits, beside the notch. Free, for macOS 26.',
  columns: [
    {
      title: 'Product',
      links: [
        { label: 'Features', href: '#features' },
        { label: 'How it works', href: '#how-it-works' },
        { label: 'FAQ', href: '#faq' },
      ],
    },
    {
      title: 'Guide',
      links: [
        { label: 'Install', href: site.install, external: true },
        { label: 'Sign in to B and C', href: site.signIn, external: true },
        { label: 'Add a copy', href: site.addCopy, external: true },
        { label: 'Uninstall', href: site.undo, external: true },
      ],
    },
    {
      title: 'Project',
      links: [
        { label: 'GitHub', href: site.repo, external: true },
        { label: 'PRD', href: site.prd, external: true },
        { label: 'claude-usage', href: site.cli, external: true },
      ],
    },
  ] satisfies Array<{ title: string; links: Link[] }>,
  legal: 'Not affiliated with Anthropic. Claude is a trademark of Anthropic.',
  copyright: '© 2026 Doug Silkstone',
}
