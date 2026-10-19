import type { ReactNode } from 'react'
import { Footer } from './Footer'
import { Nav } from './Nav'

/** Every page but the home page: the solid nav, the page, the footer. */
export function Shell({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <>
      <Nav solid />
      <main className={['page', className].filter(Boolean).join(' ')}>{children}</main>
      <Footer />
    </>
  )
}
