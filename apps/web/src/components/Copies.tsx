import type { CSSProperties } from 'react'
import { copies } from '../content'
import type { Letter } from './notch/data'
import { Badge, Ring } from './notch/Notch'
import { Button } from './ui'

type Tile = { badge: Letter } | { ring: Letter; fiveHour: number; weekly: number; out?: boolean }

/** Four columns of the app's own badges and rings, drifting up, down, up, down. Travel and
 * duration are the reference's: two groups of tiles per loop. */
const columns: Array<{ height: number; up: boolean; seconds: number; tiles: Tile[] }> = [
  {
    height: 400,
    up: true,
    seconds: 46.4,
    tiles: [
      { badge: 'A' },
      { ring: 'B', fiveHour: 0.92, weekly: 0.4 },
      { badge: 'C' },
      { ring: 'D', fiveHour: 0.18, weekly: 0.1 },
    ],
  },
  {
    height: 450,
    up: false,
    seconds: 58,
    tiles: [
      { ring: 'A', fiveHour: 0.37, weekly: 0.62 },
      { badge: 'B' },
      { ring: 'C', fiveHour: 0.12, weekly: 0.3 },
      { badge: 'D' },
    ],
  },
  {
    height: 500,
    up: true,
    seconds: 62.3,
    tiles: [
      { badge: 'C' },
      { ring: 'A', fiveHour: 0.64, weekly: 0.2 },
      { badge: 'D' },
      { ring: 'B', fiveHour: 1, weekly: 1, out: true },
      { badge: 'A' },
    ],
  },
  {
    height: 460,
    up: false,
    seconds: 69.6,
    tiles: [
      { ring: 'D', fiveHour: 0.04, weekly: 0.02 },
      { badge: 'A' },
      { ring: 'C', fiveHour: 0.55, weekly: 0.48 },
      { badge: 'B' },
    ],
  },
]

const tileSize = 64
const tileGap = 24
const groupGap = 20

function TileArt({ tile }: { tile: Tile }) {
  if ('badge' in tile) return <Badge letter={tile.badge} size={44} />
  return <Ring letter={tile.ring} fiveHour={tile.fiveHour} weekly={tile.weekly} out={tile.out} />
}

export function Copies() {
  return (
    <section className="copies" id="copies" aria-labelledby="copies-title">
      <div className="container copies__container">
        <div className="copies__text">
          <div className="copies__head">
            <h2 id="copies-title" className="t-h2">
              {copies.title}
            </h2>
            <p className="t-lead">{copies.body}</p>
          </div>
          <Button link={copies.cta} variant="glass" />
        </div>
        <div className="copies__ticker" aria-hidden="true">
          <div className="copies__fade" />
          {columns.map((column, c) => {
            const pitch = column.tiles.length * (tileSize + tileGap) - tileGap + groupGap
            return (
              <div key={column.height} className="copies__col" style={{ height: column.height }}>
                <ul
                  className={column.up ? 'copies__track' : 'copies__track copies__track--down'}
                  style={
                    {
                      '--travel': `${-2 * pitch}px`,
                      animationDuration: `${column.seconds}s`,
                    } as CSSProperties
                  }
                >
                  {[0, 1, 2, 3].map((group) => (
                    <li key={group} className="copies__group">
                      {column.tiles.map((tile, t) => (
                        <span key={`${c}-${t}`} className="copies__tile">
                          <TileArt tile={tile} />
                        </span>
                      ))}
                    </li>
                  ))}
                </ul>
              </div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
