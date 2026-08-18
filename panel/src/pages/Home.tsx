import { useEffect, useState } from 'react'
import {
  fetchActividadReciente,
  fetchAlertasContenido,
  fetchMetricasHome,
  type AlertaContenido,
  type EventoActividad,
  type MetricasHome,
} from '../lib/dashboard'

const QUICK_ACTIONS = ['Nueva temática', 'Nueva parada del camino', 'Nuevo desafío']

const METRIC_CARDS: {
  key: keyof MetricasHome
  label: string
  note: string
  color: string
}[] = [
  {
    key: 'jugadoresTotales',
    label: 'Jugadores totales',
    note: 'Desde el inicio',
    color: 'bg-brand-blue',
  },
  {
    key: 'jugadoresActivos7d',
    label: 'Activos 7 días',
    note: 'De la base total',
    color: 'bg-brand-teal',
  },
  { key: 'partidasHoy', label: 'Partidas hoy', note: 'Intentos de hoy', color: 'bg-brand-gold' },
  {
    key: 'paradasActivas',
    label: 'Paradas publicadas',
    note: 'Actualmente activas',
    color: 'bg-brand-special',
  },
]

function formatFecha(iso: string): string {
  return new Date(iso).toLocaleString('es-ES', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function textoActividad(evento: EventoActividad): string {
  if (evento.tipo === 'nuevo_registro') {
    return `Nuevo registro: ${evento.texto}`
  }
  const estrellas = Math.max(0, Math.min(3, Number(evento.detalle?.estrellas_obtenidas ?? 0)))
  const destino = evento.etiqueta ?? 'una parada'
  return `${evento.texto} superó ${destino} (${'★'.repeat(estrellas)}${'☆'.repeat(3 - estrellas)})`
}

export function Home() {
  const [metricas, setMetricas] = useState<MetricasHome | null>(null)
  const [actividad, setActividad] = useState<EventoActividad[] | null>(null)
  const [alertas, setAlertas] = useState<AlertaContenido[] | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let isMounted = true

    Promise.all([fetchMetricasHome(), fetchActividadReciente(), fetchAlertasContenido()])
      .then(([metricasResult, actividadResult, alertasResult]) => {
        if (!isMounted) return
        setMetricas(metricasResult)
        setActividad(actividadResult)
        setAlertas(alertasResult)
      })
      .catch((cargaError: unknown) => {
        if (!isMounted) return
        console.error('Error cargando el resumen del panel:', cargaError)
        setError('No se ha podido cargar el resumen del panel.')
      })

    return () => {
      isMounted = false
    }
  }, [])

  if (error) {
    return (
      <div className="rounded-2xl border border-brand-error/40 bg-brand-error/10 p-5 text-sm text-[#B3282D]">
        {error}
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-6">
      <h1 className="font-display text-3xl font-extrabold tracking-tight text-brand-night">Home</h1>

      <section className="grid grid-cols-4 gap-4">
        {METRIC_CARDS.map((card) => (
          <div key={card.key} className="rounded-2xl border border-brand-border bg-white p-5">
            <div className="flex items-center gap-2">
              <span className={`h-2 w-2 flex-none rounded-sm ${card.color}`} />
              <span className="text-[11px] font-semibold tracking-wider text-brand-night/50 uppercase">
                {card.label}
              </span>
            </div>
            <div className="mt-3 font-display text-3xl font-extrabold text-brand-night">
              {metricas ? metricas[card.key] : '—'}
            </div>
            <div className="mt-1 text-xs text-brand-night/45">{card.note}</div>
          </div>
        ))}
      </section>

      <section className="flex flex-wrap items-center gap-3 rounded-2xl border border-brand-border bg-white p-4">
        <div className="mr-1 text-[11px] font-semibold tracking-wider text-brand-night/45 uppercase">
          Accesos rápidos
        </div>
        {QUICK_ACTIONS.map((label) => (
          <span
            key={label}
            aria-disabled="true"
            title="Próximamente"
            className="cursor-not-allowed rounded-xl border-[1.5px] border-brand-border px-4 py-2.5 font-display text-sm font-extrabold text-brand-night/35"
          >
            + {label}
          </span>
        ))}
      </section>

      <section className="grid grid-cols-[1.25fr_1fr] items-start gap-5">
        <div className="overflow-hidden rounded-2xl border border-brand-border bg-white">
          <div className="border-b border-brand-border px-5 py-4">
            <h2 className="font-display text-lg font-extrabold text-brand-night">
              Actividad reciente
            </h2>
          </div>
          {actividad && actividad.length === 0 && (
            <p className="p-5 text-sm text-brand-night/45">Todavía no hay actividad que mostrar.</p>
          )}
          {actividad && actividad.length > 0 && (
            <ul>
              {actividad.map((evento, index) => (
                <li
                  key={`${evento.tipo}-${evento.ocurridoEn}-${index}`}
                  className="flex items-center gap-3 border-b border-brand-base px-5 py-3 last:border-0"
                >
                  <span className="min-w-0 flex-1 truncate text-sm text-brand-night">
                    {textoActividad(evento)}
                  </span>
                  <span className="flex-none text-xs text-brand-night/35">
                    {formatFecha(evento.ocurridoEn)}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="overflow-hidden rounded-2xl border border-brand-border bg-white">
          <div className="flex items-center gap-2.5 border-b border-brand-border px-5 py-4">
            <h2 className="font-display text-lg font-extrabold text-brand-night">
              Alertas de contenido
            </h2>
            {alertas && (
              <span className="rounded-full bg-brand-error/10 px-2.5 py-1 text-xs font-semibold text-[#B3282D]">
                {alertas.length}
              </span>
            )}
          </div>
          {alertas && alertas.length === 0 && (
            <p className="p-5 text-sm text-brand-night/45">Sin alertas de contenido por ahora.</p>
          )}
          {alertas && alertas.length > 0 && (
            <ul>
              {alertas.map((alerta, index) => (
                <li
                  key={`${alerta.tipo}-${alerta.referenciaId}-${index}`}
                  className="border-b border-brand-base px-5 py-3 last:border-0"
                >
                  <div className="text-sm font-semibold text-brand-night">{alerta.etiqueta}</div>
                  <div className="mt-1 text-xs text-brand-night/50">{alerta.titulo}</div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>
    </div>
  )
}
