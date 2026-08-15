import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import geoquestLogo from '../assets/geoquest-logo.png'
import { supabase } from '../lib/supabaseClient'
import { useAdminProfile } from '../lib/useAdminProfile'

const NAV_ITEMS = [
  { label: 'Home', enabled: true },
  { label: 'Jugadores', enabled: false },
  { label: 'Ranking', enabled: false },
  { label: 'Temáticas', enabled: false },
  { label: 'Niveles', enabled: false },
  { label: 'Preguntas/Desafíos', enabled: false },
]

export function PanelLayout({ children }: { children: ReactNode }) {
  const { nombre } = useAdminProfile()

  return (
    <div className="grid min-h-screen grid-cols-[236px_1fr] bg-brand-base">
      <aside className="sticky top-0 flex h-screen flex-col gap-6 bg-brand-night p-4">
        <div className="flex items-center gap-2.5 px-2 py-1">
          <img
            src={geoquestLogo}
            alt="GeoQuest"
            width={34}
            height={34}
            className="block rounded-lg"
          />
          <div>
            <div className="font-display text-lg font-extrabold tracking-tight text-white">
              Geo<span className="text-brand-teal">Quest</span>
            </div>
            <div className="mt-1 text-[9px] font-medium tracking-[0.2em] text-white/40 uppercase">
              Panel admin
            </div>
          </div>
        </div>

        <nav className="flex flex-col gap-0.5" aria-label="Navegación del panel">
          {NAV_ITEMS.map((item) =>
            item.enabled ? (
              <Link
                key={item.label}
                to="/"
                className="rounded-xl px-3.5 py-2.5 text-sm font-semibold text-white ring-1 ring-brand-teal/35 ring-inset bg-brand-teal/15"
              >
                {item.label}
              </Link>
            ) : (
              <span
                key={item.label}
                aria-disabled="true"
                title="Próximamente"
                className="cursor-not-allowed rounded-xl px-3.5 py-2.5 text-sm font-normal text-white/35"
              >
                {item.label}
              </span>
            ),
          )}
        </nav>
      </aside>

      <div className="flex min-w-0 flex-col">
        <header className="sticky top-0 z-10 flex h-[66px] items-center gap-4 border-b border-brand-border bg-brand-base/90 px-8 backdrop-blur-sm">
          <div className="ml-auto flex items-center gap-3.5">
            <span className="text-sm font-semibold text-brand-night">{nombre ?? '…'}</span>
            <button
              type="button"
              onClick={() => {
                void supabase.auth.signOut()
              }}
              className="rounded-lg border-[1.5px] border-brand-border bg-white px-3 py-2 text-xs font-semibold text-brand-night/70 hover:border-brand-error hover:text-brand-error"
            >
              Cerrar sesión
            </button>
          </div>
        </header>

        <main className="flex flex-col gap-6 px-8 py-8">{children}</main>
      </div>
    </div>
  )
}
