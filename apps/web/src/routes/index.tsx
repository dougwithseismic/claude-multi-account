import { createFileRoute } from '@tanstack/react-router'
import { Cards } from '../components/Cards'
import { Copies } from '../components/Copies'
import { Cta } from '../components/Cta'
import { Details } from '../components/Details'
import { Facts } from '../components/Facts'
import { Faq } from '../components/Faq'
import { Footer } from '../components/Footer'
import { Goals } from '../components/Goals'
import { Grid } from '../components/Grid'
import { Hero } from '../components/Hero'
import { Manifesto } from '../components/Manifesto'
import { Nav } from '../components/Nav'
import { Platforms } from '../components/Platforms'
import { Walkthrough } from '../components/Walkthrough'

export const Route = createFileRoute('/')({
  component: Home,
})

function Home() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Platforms />
        <Manifesto />
        <Cards />
        <Walkthrough />
        <Grid />
        <Facts />
        <Copies />
        <Details />
        <Goals />
        <Faq />
        <Cta />
      </main>
      <Footer />
    </>
  )
}
