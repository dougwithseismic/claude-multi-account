/** Made-up accounts for the mockups. Sizes are the app's own, in points. */

export const colors = {
  A: '#2F7BF5',
  B: '#F5822F',
  C: '#2FB36B',
  D: '#B04FD6',
} as const

export type Letter = keyof typeof colors

/** install.sh's colour for each letter; letters after H are grey. */
export const palette: Record<string, string> = {
  ...colors,
  E: '#E5487F',
  F: '#1FB5C1',
  G: '#E3B52B',
  H: '#E5484D',
}

export const colorOf = (letter: string) => palette[letter] ?? '#B3B3B3'

export const limitRed = '#FF453A'
export const alertOrange = '#FF9F0A'

export type Window = {
  label: string
  /** Percent used, 0 to 100. */
  used: number
  reset: string
  /** How far through the window it is, 0 to 1; none at 100%. */
  pace?: number
  /** At 100%, the wait left, 0 to 1. */
  wait?: number
}

export type Copy = {
  letter: Letter
  plan?: string
  windows: Window[]
}

export const notch = { width: 186, height: 32, flare: 6, overlap: 14, ringSize: 16, ringSpacing: 6 }

export const sample: Copy[] = [
  {
    letter: 'A',
    plan: 'Max 20x',
    windows: [
      { label: '5-hour', used: 37, reset: 'resets in 2h 10m', pace: 0.57 },
      { label: 'Weekly', used: 62, reset: 'resets in 2d 23h', pace: 0.58 },
      { label: 'Weekly · Fable', used: 20, reset: 'resets in 2d 23h', pace: 0.58 },
    ],
  },
  {
    letter: 'B',
    plan: 'Team',
    windows: [
      { label: '5-hour', used: 92, reset: 'resets in 1h 4m', pace: 0.79 },
      { label: 'Weekly · Fable', used: 100, reset: 'back in 1d 23h', wait: 0.28 },
    ],
  },
  {
    letter: 'C',
    plan: 'Pro',
    windows: [
      { label: '5-hour', used: 12, reset: 'resets in 4h 21m', pace: 0.13 },
      { label: 'Weekly', used: 30, reset: 'resets in 3d 5h', pace: 0.55 },
    ],
  },
]

/** The ring's two figures: the 5-hour window, and the fullest weekly one. */
export function ringOf(copy: Copy) {
  const fiveHour = copy.windows.find((w) => w.label === '5-hour')
  const weekly = Math.max(0, ...copy.windows.filter((w) => w.label !== '5-hour').map((w) => w.used))
  return {
    fiveHour: fiveHour?.wait ?? (fiveHour?.used ?? 0) / 100,
    out: fiveHour?.wait != null,
    weekly: weekly / 100,
  }
}
