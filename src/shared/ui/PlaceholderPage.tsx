import { useLocation } from 'react-router-dom'

export function PlaceholderPage() {
  const location = useLocation()

  return (
    <section className="placeholder-page">
      <span className="eyebrow">COOST MODULE</span>
      <h1>{location.pathname.replace('/', '').toUpperCase()}</h1>
      <p>Bu modul Foundation tamamlandiktan sonra gelistirilecek.</p>
    </section>
  )
}